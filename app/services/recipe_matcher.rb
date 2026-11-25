class RecipeMatcher
  def initialize(ingredient_ids, meal_type: nil)
    @ingredient_ids = ingredient_ids.map(&:to_i).uniq
    @meal_type = meal_type
  end

  def call
    return [] if @ingredient_ids.empty?

    selected_ingredients = Ingredient
      .where(id: @ingredient_ids)
      .index_by(&:id)

    return [] if selected_ingredients.empty?

    recipes = Recipe.where(recommendation_eligible: true)

    if @meal_type.present? && @meal_type != "any"
      recipes = recipes.where("? = ANY(meal_types)", @meal_type)
    end

    results = recipes.includes(ingredients: :ingredient_family).map do |recipe|
      recipe_ingredients = recipe.ingredients.uniq(&:id)

      # Each selected ingredient can satisfy only one recipe ingredient.
      available_ingredients = selected_ingredients.values.dup

      exact_ids = []
      related_ids = []
      missing_ids = []

      # First, prioritize exact matches.
      unmatched_ingredients = []

      recipe_ingredients.each do |required|
        match = available_ingredients.find do |available|
          exact_match?(available, required)
        end

        if match
          exact_ids << required.id
          available_ingredients.delete(match)
        else
          unmatched_ingredients << required
        end
      end

      # Then look for related ingredients among those still available.
      unmatched_ingredients.each do |required|
        match = available_ingredients.find do |available|
          related_match?(available, required)
        end

        if match
          related_ids << required.id
          available_ingredients.delete(match)
        else
          missing_ids << required.id
        end
      end

      matching_ids = exact_ids + related_ids

      additional_ingredient_count = missing_ids.count do |id|
        recipe_ingredients.find { |ingredient| ingredient.id == id }.is_pantry_staple == false
      end

      {
        recipe: recipe,
        matching_ids: matching_ids,
        missing_ids: missing_ids,
        matching_count: matching_ids.count,
        missing_count: missing_ids.count,
        exact_matching_ids: exact_ids,
        related_matching_ids: related_ids,
        exact_matching_count: exact_ids.count,
        related_matching_count: related_ids.count,
        additional_ingredient_count: additional_ingredient_count
      }
    end

    results = results.select do |result|
      result[:matching_count] > 0
    end

    results = results.sort_by do |result|
      [
        -result[:matching_count],
        -result[:exact_matching_count],
        result[:additional_ingredient_count]
      ]
    end

    results.first(3)
  end

  private

  def exact_match?(available, required)
    return true if available.id == required.id
    return false if available.review_needed || required.review_needed

    available.equivalence_key.present? &&
      available.equivalence_key == required.equivalence_key
  end

  def related_match?(available, required)
    return false if available.review_needed || required.review_needed
    return false if available.ingredient_family_id.nil?
    return false if required.ingredient_family_id.nil?

    available.ingredient_family_id == required.ingredient_family_id &&
      available.equivalence_key != required.equivalence_key
  end
end
