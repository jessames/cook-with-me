class RecipesController < ApplicationController
  def index
    @recipes = current_user.recipes.where(cooked: true).limit(15)
  end

  def results
    ingredient_ids = Array(params[:ingredients]).reject(&:blank?).map(&:to_i)
    @meal_type = params[:meal_type].presence || "any"

    @results = RecipeMatcher.new(ingredient_ids, meal_type: @meal_type).call
  end

  def show
    @recipe = Recipe.find(params[:id])
  end
end
