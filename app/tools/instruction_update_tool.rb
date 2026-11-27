class InstructionUpdateTool < RubyLLM::Tool
  description "Updates the current recipe's instruction when the user reports a cooking problem or missing ingredient. Examples: 'I burnt the chicken' or 'I don't have enough cream'. Use the report to give an immediate recovery step and adapt the remaining instructions."

  parameter :situation, desc: "The problem, limitation, or missing ingredient the user reported"

  def initialize (recipe:)
    @recipe = recipe
  end

  def execute(situation:)
    return {error: "Please describe what happened."} if situation.blank?
    instruction_records = @recipe.instructions.order(:instruction_number)
    current_text_list = instruction_records.map do |instr|
      "Step #{instr.instruction_number}: #{instr.instruction_content}"
    end.join("\n")

    response = RubyLLM.chat
      .with_instructions(<<~PROMPT)
        You are updating a recipe based on a user's problem or limitation.

        Return the revised instructions as a numbered list.
        Maintain the original step numbers.

        Return ONLY the revised list of steps. No preamble.
      PROMPT
      .ask(<<~INPUT)
        <current_instructions>
        #{current_text_list}
        </current_instructions>

        <user_situation>
        #{situation}
        </user_situation>
      INPUT

    revised_content = response.content.to_s.strip
    return { error: "Could not generate revised instructions." } if revised_content.blank?

    revised_steps = revised_content.scan(/^\d+[\.\)]\s*(.*)$/).flatten

    instruction_records.each_with_index do |record, index|
      if revised_steps[index]
        record.update!(instruction_content: revised_steps[index])
      end
    end

    {
      success: true,
      updated_steps: revised_steps.count,
      recipe_id: @recipe.id
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.record.errors.full_messages.to_sentence }
  end
end
