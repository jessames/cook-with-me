class InstructionUpdateTool < RubyLLM::Tool
  description "Edit and update the instruction content based on chats"

  param :cooking_query, desc: "The issue described by the user"

end
