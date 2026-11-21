class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def index
    @favorites = current_user.favorites.includes(:recipe).order(created_at: :desc)
  end

  def create
    @recipe = Recipe.find(params[:recipe_id])
    @favorite = current_user.favorites.find_or_initialize_by(recipe: @recipe)

    if @favorite.save
      redirect_to recipe_path(@recipe, ingredients: params[:ingredients]),
              notice: "Recipe added to favorites!"
    else
      redirect_to recipe_path(@recipe, ingredients: params[:ingredients]),
              alert: "Could not add recipe to favorites."
    end
  end

  def destroy
    @favorite = current_user.favorites.find(params[:id])
    @recipe = @favorite.recipe

    @favorite.destroy

    redirect_to recipe_path(@recipe, ingredients: params[:ingredients]),
              notice: "Recipe removed from favorites."
  end
end
