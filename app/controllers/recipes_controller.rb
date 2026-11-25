class RecipesController < ApplicationController
  def index
    @recipes = Recipe.where(cooked: true).limit(15)
    @favorite_ids = current_user.favorites.pluck(:recipe_id)
  end

  def results
    ingredient_ids = Array(params[:ingredients]).reject(&:blank?).map(&:to_i)
<<<<<<< HEAD
    @meal_type = params[:meal_type].presence || "any"

    @results = RecipeMatcher.new(ingredient_ids, meal_type: @meal_type).call
=======
    @favorite_ids = current_user.favorites.pluck(:recipe_id)
>>>>>>> origin/master
  end

  def show
    @recipe = Recipe.find(params[:id])
  end
end
