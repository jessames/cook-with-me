class RecipesController < ApplicationController
  def index
    @recipes = Recipe.where(cooked: true).limit(15)
  end
end
