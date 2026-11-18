class RecipesController < ApplicationController
  def index
    @recipes = current_user.recipes.where(cooked: true).limit(15)
  end

  def results
    ingredient_ids = Array(params[:ingredient_ids]).reject(&:blank?).map(&:to_i)

    @results = RecipeMatcher.new(ingredient_ids).call
  end
end
