class InstructionsController < ApplicationController
  def index
   @cook_session = current_user.cook_sessions.find(params[:cook_session_id])
   @recipe = @cook_session.recipe
   @instructions = @recipe.instructions
  end
end
