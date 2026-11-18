class RecipesController < ApplicationController
  def results
    ingredient_ids = Array(params[:ingredient_ids]).reject(&:blank?).map(&:to_i)

    @results = RecipeMatcher.new(ingredient_ids).call
  end
end
