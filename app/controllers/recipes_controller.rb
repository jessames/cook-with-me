class RecipesController < ApplicationController
  def results
    ingredient_ids = Array(params[:ingredient_ids]).reject(&:blank?).map(&:to_i)

    @results = RecipeMatcher.new(ingredient_ids).call

    render json: @results.map { |result|
      {
        id: result[:recipe].id,
        recipe: result[:recipe].name,
        matching_ids: result[:matching_ids],
        missing_ids: result[:missing_ids],
        matching_count: result[:matching_count],
        missing_count: result[:missing_count]
      }
    }
  end
end
