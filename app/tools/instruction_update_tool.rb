class InstructionUpdateTool < RubyLLM::Tool
  description "Updates the current recipe's instruction when the user reports a cooking problem or missing ingredient. Examples: 'I burnt the chicken' or 'I don't have enough cream'. Use the report to give an immediate recovery step and adapt the remaining instructions."

  param :situation, desc: "The cooking issue or missing ingredient the user reported"

  def initialize (recipe:)
    @recipe = recipe
  end

  def execute(situation:)
    return {error: "Please describe what happened."} if situation.blank?
  end

end
