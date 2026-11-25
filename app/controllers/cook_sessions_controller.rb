class CookSessionsController < ApplicationController
  before_action :set_cook_session, only: :destroy

  def new
    @recipes = current_user.recipes
    @recipe = @recipes.find_by(id: params[:recipe_id])
    @cook_session = current_user.cook_sessions.build(recipe: @recipe)
  end

  def create
    recipe = Recipe.find(params[:recipe_id])
    @cook_session = current_user.cook_sessions.build(recipe: recipe)

  def destroy
    CookSession.transaction do
      @cook_session.recipe.update!(cooked: true)
      @cook_session.destroy!
      redirect_to recipes_path, notice: "Recipe added to recent recipes."
    end
  end

  private

  def set_cook_session
    @cook_session = current_user.cook_sessions.find(params[:id])
  end

  def cook_session_params
    params.require(:cook_session).permit(:recipe_id)
  end
end
end
