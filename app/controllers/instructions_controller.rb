class InstructionsController < ApplicationController
  def show
    @cook_session = current_user.cook_sessions.find(params[:cook_session_id])
    @recipe = @cook_session.recipe
    @instruction = @recipe.instructions.find(params[:id])

    @step = @instruction.instruction_content
    @step_number = @instruction.instruction_number
    @total_steps = @recipe.instructions.count

    @prev_instruction = @recipe.instructions
                               .where("instruction_number < ?", @step_number)
                               .order(instruction_number: :desc).first

    @next_instruction = @recipe.instructions
                               .where("instruction_number > ?", @step_number)
                               .order(instruction_number: :asc).first
  end
end
