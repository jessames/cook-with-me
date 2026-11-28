class RecipeMatcher
  ROLE_WEIGHTS = {
    "protein" => 5, "starch" => 3, "produce" => 2, "dairy" => 2, "aromatic" => 1, "seasoning" => 1
  }.freeze
  DEFAULT_WEIGHT = 1
  RELATED_MATCH_FACTOR = 0.75
  MISSING_PENALTY = 0.5
  RESULT_LIMIT = 3
  MEAL_SIZED_TYPES = %w[breakfast lunch dinner any].freeze
  FILLING_ROLES = %w[protein starch].freeze

  def initialize(ingredient_ids, meal_type: nil)
    @ingredient_ids = ingredient_ids.map(&:to_i).uniq
    @meal_type = meal_type
  end

  def call
    selected = Ingredient.where(id: @ingredient_ids).to_a
    return [] if selected.empty?

    results = candidate_recipes.map { |recipe| evaluate(recipe, selected) }
    ranked = rank(results.select { |result| result[:matching_count].positive? })
    ranked = filling_first(ranked) if meal_sized?
    ranked.first(RESULT_LIMIT)
  end

  private

  def candidate_recipes
    recipes = Recipe.where(recommendation_eligible: true)
    recipes = recipes.where("? = ANY(meal_types)", @meal_type) if @meal_type.present? && @meal_type != "any"
    recipes.includes(:ingredients)
  end

  def rank(results)
    results.sort_by do |result|
      [-result[:score], result[:additional_ingredient_count], -result[:exact_matching_count], result[:recipe].id]
    end
  end

  # For meal-sized requests, filling recipes always outrank non-filling ones;
  # non-filling recipes only fill slots left over.
  def filling_first(results)
    filling, light = results.partition { |result| result[:filling] }
    filling + light
  end

  def meal_sized?
    @meal_type.blank? || MEAL_SIZED_TYPES.include?(@meal_type)
  end

  def evaluate(recipe, selected)
    required = recipe.ingredients.uniq(&:id)
    exact, related, missing = match_ingredients(required, selected.dup)
    build_result(recipe, exact, related, missing).merge(
      filling: required.any? { |ingredient| FILLING_ROLES.include?(ingredient.role) }
    )
  end

  # Each selected ingredient can satisfy only one recipe ingredient:
  # exact matches are claimed first, then related (same family) matches.
  def match_ingredients(required, available)
    exact, unmatched = claim(required, available) { |have, need| exact_match?(have, need) }
    related, missing = claim(unmatched, available) { |have, need| related_match?(have, need) }
    [exact, related, missing]
  end

  def claim(required, available)
    required.partition do |need|
      match = available.find { |have| yield(have, need) }
      available.delete(match) if match
      match
    end
  end

  def build_result(recipe, exact, related, missing)
    matching = exact + related
    {
      recipe: recipe,
      matching_ids: matching.map(&:id), missing_ids: missing.map(&:id),
      matching_count: matching.size, missing_count: missing.size,
      exact_matching_ids: exact.map(&:id), related_matching_ids: related.map(&:id),
      exact_matching_count: exact.size, related_matching_count: related.size,
      additional_ingredient_count: missing.count { |ingredient| !ingredient.is_pantry_staple },
      score: score(exact, related, missing)
    }
  end

  def score(exact, related, missing)
    used = total_weight(exact) + (RELATED_MATCH_FACTOR * total_weight(related))
    needed = total_weight(missing.reject(&:is_pantry_staple))
    (used - (MISSING_PENALTY * needed)).to_f
  end

  def total_weight(ingredients)
    ingredients.sum { |ingredient| ROLE_WEIGHTS.fetch(ingredient.role, DEFAULT_WEIGHT) }
  end

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
