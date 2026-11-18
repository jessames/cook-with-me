class RecipesController < ApplicationController
  def index
    @recipes = current_user.recipes.where(cooked: true).limit(15)
  end

end
