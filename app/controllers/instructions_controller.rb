class InstructionsController < ApplicationController
  def show
  @cook_session = current_user.cook_sessions.find(params[:cook_session_id])
  @recipe = @cook_session.recipe
  @instruction = @recipe.instructions.find(params[:id])

  text = @instruction.instruction_content.to_s.gsub("\\r\\n", "\n")
  @steps = text.split(/\r?\n/).map(&:strip).reject(&:blank?)

  @step_number = params.fetch(:step, "1").to_i
  raise ActiveRecord::RecordNotFound unless @step_number.between?(1, @steps.length)

  @step = @steps[@step_number - 1]
  end
end
