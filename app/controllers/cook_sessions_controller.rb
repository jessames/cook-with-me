class CookSessionsController < ApplicationController
  before_action :set_cook_session, only: :destroy

  def new
    @cook_session = current_user.cook_sessions.build
    @recipes = current_user.recipes
  end

  def create
    recipe = current_user.recipe.find(cook_session_params[:recipe_id])
    @cook_session = current_user.cook_sessions.build(recipe: recipe)
    if @cook_session.save
      redirect_to redirect_to cook_session_instructions_path(@cook_session), notice: "Let's get cooking!"
    else
      @recipes = current_user.recipes
      render :new, status: :unprocessable_entity
    end
  end

  def destory
    CookSession.transaction do
      @cook_session.recipe.update!(cooked: true)
      @cook_session.destroy!
      # delete chat
  end
  redirect_to recipes_path, notice: "Recipe added to recent recipes."
end

private

def set_cook_session
  @cook_session = current_user.cook_sessions.find(params[:id])
end

def cook_session_params
  params.require(:cook_session).permit(:recipe_id)
end
