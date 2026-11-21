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

  if @cook_session.save
    instruction = recipe.instructions.order(:instruction_number, :id).first!
    redirect_to cook_session_instruction_path(@cook_session, instruction, step: 1),
                notice: "Let's get cooking!"
  else
    @recipes = current_user.recipes
    @recipe = recipe
    render "cook_sessions/new", status: :unprocessable_entity
  end
end

  def destroy
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
end
