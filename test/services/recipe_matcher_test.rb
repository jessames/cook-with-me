require "test_helper"

class RecipeMatcherTest < ActiveSupport::TestCase
  def ing(name, role:, staple: false, family: nil, equivalence: nil, review: false)
    Ingredient.create!(name:, role:, is_pantry_staple: staple, ingredient_family: family,
                       equivalence_key: equivalence, review_needed: review)
  end

  def recipe(name, *ingredients, meal_types: %w[lunch dinner], eligible: true)
    Recipe.create!(name:, meal_types:, recommendation_eligible: eligible).tap do |r|
      ingredients.each { |i| r.measurements.create!(ingredient: i) }
    end
  end

  def results(selected, **opts) = RecipeMatcher.new(selected.map(&:id), **opts).call
  def names(selected, **opts) = results(selected, **opts).map { _1[:recipe].name }
  def result_for(selected, name, **opts) = results(selected, **opts).find { _1[:recipe].name == name }

  test "protein-and-starch dish beats onion-only dish with fewer missing" do
    chicken = ing("chicken", role: "protein")
    rice = ing("rice", role: "starch")
    onion = ing("onion", role: "aromatic")
    recipe("A", chicken, rice, onion, ing("chorizo", role: "protein"), ing("peppers", role: "produce"),
           ing("stock", role: "seasoning"), ing("paprika", role: "seasoning"))
    recipe("B", onion, ing("beef", role: "protein"))

    selected = [chicken, rice, onion]
    assert_equal "A", names(selected).first
    assert_in_delta 4.5, result_for(selected, "A")[:score]
    assert_in_delta(-1.5, result_for(selected, "B")[:score])
  end

  test "lighter missing ingredients win among equal matches" do
    chicken = ing("chicken", role: "protein")
    recipe("Needs pork", chicken, ing("pork", role: "protein"))
    recipe("Needs parsley", chicken, ing("parsley", role: "aromatic"))
    assert_equal ["Needs parsley", "Needs pork"], names([chicken])
  end

  test "staples never count as missing" do
    chicken = ing("chicken", role: "protein")
    recipe("Salted chicken", chicken, ing("salt", role: "seasoning", staple: true))
    result = results([chicken]).first
    assert_equal 1, result[:missing_count]
    assert_equal 0, result[:additional_ingredient_count]
    assert_in_delta 5.0, result[:score]
  end

  test "related match scores 0.75 of the weight" do
    family = IngredientFamily.create!(name: "chicken meat")
    thighs = ing("thighs", role: "protein", family:, equivalence: -1)
    recipe("Breast dish", ing("breast", role: "protein", family:, equivalence: -2))
    result = results([thighs]).first
    assert_in_delta 3.75, result[:score]
    assert_equal 1, result[:related_matching_count]
  end

  test "review_needed blocks equivalence and family matching" do
    family = IngredientFamily.create!(name: "chicken meat")
    thighs = ing("thighs", role: "protein", family:, equivalence: -1)
    recipe("Breast dish", ing("breast", role: "protein", family:, equivalence: -2, review: true))
    assert_empty results([thighs])
  end

  test "meal type filter and eligibility still apply" do
    sugar = ing("sugar", role: "seasoning")
    recipe("Cake", sugar, meal_types: %w[dessert])
    recipe("Hidden", sugar, eligible: false)
    assert_empty results([sugar], meal_type: "lunch")
    assert_equal ["Cake"], names([sugar])
  end

  test "ingredient with no role weighs 1" do
    chicken = ing("chicken", role: "protein")
    mystery = ing("mystery", role: nil)
    recipe("Mystery chicken", chicken, mystery)
    assert_in_delta 6.0, results([chicken, mystery]).first[:score]
  end

  test "blank and unknown ids return empty" do
    assert_equal [], RecipeMatcher.new(["", "999999"]).call
  end

  test "duplicate measurement counts once" do
    chicken = ing("chicken", role: "protein")
    recipe("Double chicken", chicken, chicken)
    result = results([chicken]).first
    assert_in_delta 5.0, result[:score]
    assert_equal 1, result[:matching_count]
  end

  test "two family members used once each" do
    family = IngredientFamily.create!(name: "chicken meat")
    thighs = ing("thighs", role: "protein", family:, equivalence: -1)
    breast = ing("breast", role: "protein", family:, equivalence: -2)
    recipe("Mixed chicken", breast, thighs)
    result = results([thighs, breast]).first
    assert_equal 2, result[:matching_count]
    assert_equal 2, result[:exact_matching_count]
  end

  def salad_and_stew(meal_types: %w[lunch dinner])
    tomato = ing("tomato", role: "produce")
    cucumber = ing("cucumber", role: "produce")
    lettuce = ing("lettuce", role: "produce")
    recipe("Salad", tomato, cucumber, lettuce, meal_types:)
    recipe("Stew", tomato, ing("potatoes", role: "starch"), meal_types:)
    [ing("salmon", role: "protein"), tomato, cucumber, lettuce]
  end

  test "lunch fallback prefers filling meal over salad" do
    assert_equal "Stew", names(salad_and_stew, meal_type: "lunch").first
  end

  test "non-filling fills remaining slots" do
    assert_equal %w[Stew Salad], names(salad_and_stew, meal_type: "lunch")
  end

  test "snack ignores the filling rule" do
    selected = salad_and_stew(meal_types: %w[snack])
    assert_equal %w[Salad Stew], names(selected, meal_type: "snack")
  end

  test "nil meal type behaves like any" do
    selected = salad_and_stew
    assert_equal %w[Stew Salad], names(selected, meal_type: nil)
    assert_equal %w[Stew Salad], names(selected, meal_type: "any")
  end

  test "filling flag reported" do
    selected = salad_and_stew
    assert result_for(selected, "Stew")[:filling]
    refute result_for(selected, "Salad")[:filling]
  end

  test "staples-only selection still returns recipes" do
    butter = ing("butter", role: "seasoning", staple: true)
    recipe("Buttered toast", butter)
    result = results([butter]).first
    assert_equal "Buttered toast", result[:recipe].name
    assert_in_delta 1.0, result[:score]
  end
end
