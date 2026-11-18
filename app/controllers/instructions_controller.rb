class InstructionsController < ApplicationController
  def new
  end

  def show
   @cook_session = current_user.cook_sessions.find(params[:cook_session_id])
   @recipe = @cook_session.recipe
   @instructions = @recipe.instructions
  end
end
