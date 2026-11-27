require "csv"
require "json"
require_relative "../../lib/reviewed_instruction_cleanup"

class RecipeDataImportService
  def call
    load_data
    validate_data

    ActiveRecord::Base.transaction do
      create_missing_ingredients
      import_ingredient_classifications
      apply_recipe_repairs
      import_recipe_classifications
      validate_results
    end
  end

  private

  def load_data
    data_path = Rails.root.join("db", "data")

    @ingredient_rows = CSV.read(
      data_path.join("ingredient_classification.csv"),
      headers: true
    )

    @recipe_repairs = JSON.parse(
      File.read(data_path.join("recipe_repairs.json"))
    )

    @recipe_rows = CSV.read(
      data_path.join("recipe_classification.csv"),
      headers: true
    )

    puts "Ingredient classifications: #{@ingredient_rows.size}"
    puts "Recipe repairs: #{@recipe_repairs.fetch("recipes").size}"
    puts "Recipe classifications: #{@recipe_rows.size}"
  end

  def validate_data
    ingredient_names = @ingredient_rows.map do |row|
      row["ingredient_name"]
    end

    recipe_external_ids = @recipe_rows.map do |row|
      row["external_id"]
    end

    new_ingredient_names = @recipe_repairs.fetch("ingredients").map do |ingredient|
      ingredient["name"]
    end

    repaired_recipe_ids = @recipe_repairs.fetch("recipes").map do |recipe|
      recipe["external_id"].to_s
    end

    # Check for duplicates
    raise "Duplicate ingredient names" unless ingredient_names.uniq.size == ingredient_names.size

    raise "Duplicate recipe external IDs" unless recipe_external_ids.uniq.size == recipe_external_ids.size

    # Check equivalence references
    equivalence_names = @ingredient_rows.map do |row|
      row["equivalence_ingredient_name"]
    end

    invalid_references = equivalence_names - ingredient_names

    raise "Invalid equivalence references: #{invalid_references}" if invalid_references.any?

    # Check that required ingredients exist or will be created
    available_ingredients = Ingredient.pluck(:name) + new_ingredient_names

    missing_ingredients = ingredient_names - available_ingredients

    raise "Missing ingredients: #{missing_ingredients}" if missing_ingredients.any?

    # Check that required recipes exist
    missing_recipes = recipe_external_ids - Recipe.pluck(:external_id)

    raise "Missing recipes: #{missing_recipes}" if missing_recipes.any?

    # Check that repaired recipes are included in the classifications
    invalid_repairs = repaired_recipe_ids - recipe_external_ids

    raise "Invalid recipe repairs: #{invalid_repairs}" if invalid_repairs.any?

    puts "Data validation passed!"
  end

  def create_missing_ingredients
    created = 0

    @recipe_repairs.fetch("ingredients").each do |data|
      ingredient = Ingredient.find_or_initialize_by(
        name: data.fetch("name")
      )

      if ingredient.new_record?
        ingredient.image_url = data["image_url"]
        ingredient.save!
        created += 1
      end
    end

    puts "New ingredients created: #{created}"
  end

  def import_ingredient_classifications
    ingredients = Ingredient.all.index_by(&:name)
    families = {}

    # Find or create all ingredient families
    @ingredient_rows.map { |row| row["family_name"] }.uniq.each do |name|
      families[name] = IngredientFamily.find_or_create_by!(name: name)
    end

    # Apply classifications to each ingredient
    @ingredient_rows.each do |row|
      ingredient = ingredients.fetch(row["ingredient_name"])

      equivalence_ingredient = ingredients.fetch(
        row["equivalence_ingredient_name"]
      )

      ingredient.update!(
        ingredient_family: families.fetch(row["family_name"]),
        equivalence_key: equivalence_ingredient.id,
        relationship_type: row["relationship_type"],
        review_needed: row["review_needed"] == "true",
        is_pantry_staple: row["is_pantry_staple"] == "true"
      )
    end

    puts "Ingredient classifications imported: #{@ingredient_rows.size}"
  end

  def apply_recipe_repairs
    @recipe_repairs.fetch("recipes").each do |data|
      recipe = Recipe.find_by!(
        external_id: data.fetch("external_id")
      )

      recipe.update!(
        name: data.fetch("name")
      )

      sync_measurements(recipe, data.fetch("measurements"))
      sync_instructions(recipe, reviewed_instructions(data))
    end

    puts "Recipe repairs applied: #{@recipe_repairs.fetch("recipes").size}"
  end

  def sync_measurements(recipe, measurements)
    retained_ids = []

    measurements.each do |data|
      ingredient = Ingredient.find_by!(
        name: data.fetch("ingredient_name")
      )

      measurement = recipe.measurements.find_or_initialize_by(
        ingredient: ingredient
      )

      measurement.update!(
        measure_value: data["measure_value"],
        measure_unit: data["measure_unit"]
      )

      retained_ids << measurement.id
    end

    recipe.measurements.where.not(id: retained_ids).destroy_all
  end

  def reviewed_instructions(data)
    instructions = data.fetch("instructions").sort_by { |step| step.fetch("instruction_number") }
    texts = instructions.map { |step| step.fetch("instruction_content") }
    cleaned = ReviewedInstructionCleanup.normalize(data.fetch("external_id"), texts)
    return instructions if cleaned == texts

    cleaned.each_with_index.map do |text, index|
      { "instruction_number" => index + 1, "instruction_content" => text }
    end
  end

  def sync_instructions(recipe, instructions)
    retained_ids = []

    instructions.each do |data|
      instruction = recipe.instructions.find_or_initialize_by(
        instruction_number: data.fetch("instruction_number")
      )

      instruction.update!(
        instruction_content: data.fetch("instruction_content")
      )

      retained_ids << instruction.id
    end

    recipe.instructions.where.not(id: retained_ids).destroy_all
  end

  def import_recipe_classifications
    recipes = Recipe.all.index_by(&:external_id)

    @recipe_rows.each do |row|
      recipe = recipes.fetch(row["external_id"])

      recipe.update!(
        source_category: row["source_category"],
        dish_role: row["dish_role"],
        meal_types: row["meal_types"].to_s.split(";"),
        recommendation_eligible: row["recommendation_eligible"] == "true",
        review_needed: row["review_needed"] == "true"
      )
    end

    puts "Recipe classifications imported: #{@recipe_rows.size}"
  end

  def validate_results
    validate_ingredient_results
    validate_recipe_results
    validate_repair_results

    puts "All import validations passed!"
  end

  def validate_ingredient_results
    ingredients = Ingredient.includes(:ingredient_family).index_by(&:name)

    @ingredient_rows.each do |row|
      ingredient = ingredients.fetch(row["ingredient_name"])

      equivalence_ingredient = ingredients.fetch(
        row["equivalence_ingredient_name"]
      )

      valid = (
        ingredient.ingredient_family&.name == row["family_name"] &&
        ingredient.equivalence_key == equivalence_ingredient.id &&
        ingredient.relationship_type == row["relationship_type"] &&
        ingredient.review_needed == (row["review_needed"] == "true") &&
        ingredient.is_pantry_staple == (row["is_pantry_staple"] == "true")
      )

      raise "Ingredient validation failed: #{ingredient.name}" unless valid
    end

    puts "Ingredient classifications validated: #{@ingredient_rows.size}"
  end

  def validate_recipe_results
    recipes = Recipe.all.index_by(&:external_id)

    @recipe_rows.each do |row|
      recipe = recipes.fetch(row["external_id"])

      valid = (
        recipe.name == row["recipe_name"] &&
        recipe.source_category == row["source_category"] &&
        recipe.dish_role == row["dish_role"] &&
        recipe.meal_types.sort == row["meal_types"].to_s.split(";").sort &&
        recipe.recommendation_eligible == (row["recommendation_eligible"] == "true") &&
        recipe.review_needed == (row["review_needed"] == "true")
      )

      raise "Recipe validation failed: #{recipe.name}" unless valid
    end

    puts "Recipe classifications validated: #{@recipe_rows.size}"
  end

  def validate_repair_results
    @recipe_repairs.fetch("recipes").each do |data|
      recipe = Recipe.find_by!(
        external_id: data.fetch("external_id")
      )

      actual_measurements = recipe.measurements.includes(:ingredient).map do |measurement|
        {
          "ingredient_name" => measurement.ingredient.name,
          "measure_value" => measurement.measure_value,
          "measure_unit" => measurement.measure_unit
        }
      end

      expected_measurements = data.fetch("measurements")

      actual_instructions = recipe.instructions.order(:instruction_number).map do |instruction|
        {
          "instruction_number" => instruction.instruction_number,
          "instruction_content" => instruction.instruction_content
        }
      end

      expected_instructions = reviewed_instructions(data)

      unless actual_measurements.sort_by { |m| m["ingredient_name"] } ==
            expected_measurements.sort_by { |m| m["ingredient_name"] }
        raise "Measurement validation failed: #{recipe.name}"
      end

      unless actual_instructions == expected_instructions
        raise "Instruction validation failed: #{recipe.name}"
      end

      raise "Recipe name validation failed: #{recipe.name}" unless recipe.name == data["name"]
    end

    puts "Recipe repairs validated: #{@recipe_repairs.fetch("recipes").size}"
  end
end
