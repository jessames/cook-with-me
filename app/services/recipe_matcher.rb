class RecipeMatcher
  def initialize(ingredient_ids)
    @ingredient_ids = ingredient_ids
  end

  def call
    return [] if @ingredient_ids.empty?

    results = Recipe.includes(:ingredients).map do |recipe|
      recipe_ids = recipe.ingredients.map(&:id)

      matching_ids = recipe_ids & @ingredient_ids
      missing_ids = recipe_ids - @ingredient_ids

      {
        recipe: recipe,
        matching_ids: matching_ids,
        missing_ids: missing_ids,
        matching_count: matching_ids.count,
        missing_count: missing_ids.count
      }
    end

    results = results.select do |result|
      result[:matching_count] > 0
    end

    results = results.sort_by do |result|
      # [result[:missing_count], -result[:matching_count]]
      total = result[:matching_count] + result[:missing_count]
      [-result[:matching_count].to_f/total, -result[:matching_count]]
    end

    results.first(3)
  end
end
