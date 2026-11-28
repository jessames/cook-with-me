require "csv"

# Applies only `role` and `is_pantry_staple` from the ingredient classification
# CSV. Used by a data migration for existing databases, where re-running the
# full RecipeDataImportService is unsafe.
class IngredientRoleStapleSync
  def initialize(rows = CSV.read(Rails.root.join("db/data/ingredient_classification.csv"), headers: true))
    @rows = rows
  end

  def call
    errors = IngredientClassificationCheck.errors(@rows)
    raise "Invalid ingredient roles: #{errors}" if errors.any?

    ActiveRecord::Base.transaction { apply_rows }

    @rows.size
  end

  private

  def apply_rows
    ingredients = Ingredient.where(name: @rows.map { |row| row["ingredient_name"] }).index_by(&:name)

    @rows.each do |row|
      ingredient = ingredients[row["ingredient_name"]]
      raise "Missing ingredient: #{row['ingredient_name']}" unless ingredient

      ingredient.update!(role: row["role"], is_pantry_staple: row["is_pantry_staple"] == "true")
    end
  end
end
