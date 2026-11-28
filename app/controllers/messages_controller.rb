class MessagesController < ApplicationController

  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful cooking assistant.

    Your job is to help users while they are actively
    preparing a recipe.

    You can:
    - Answer questions about cooking techniques.
    - Help troubleshoot problems during cooking.
    - Suggest substitutions for missing ingredients.
    - Suggest adjustments to cooking times and temperatures.
    - Suggest modifications to the current recipe.

    Always consider the recipe and the user's current
    cooking step when answering.

    Be practical, clear, and concise. The user may be
    cooking while chatting with you, so prioritize
    actionable instructions.

    Do not assume ingredients or equipment the user
    has not mentioned.

    If you suggest a recipe modification, explain
    what should change and why.

    You have access to one tool:
      - InstructionUpdateTool:
        - Use the tool when the user reports a problem, missing ingredient, requested recipe change, or limitation that makes a recipe step difficult or impossible for them.
        - Do not use it for unrelated cooking questions.
        - Combine related information from the current message and relevant earlier messages.
        - Adapt the affected step and any remaining steps that depend on it. Preserve unaffected steps, and do not assume a step is unfinished if the user says they completed it.
        - Respect the user's stated needs without making assumptions about their abilities or circumstances.
        - Do not invent ingredients, quantities, equipment, or details about what happened. Suggest an alternative method only when it can be done with information already available; otherwise, ask what tools or ingredients the user has.
  PROMPT

  def index
    @cook_session = current_user.cook_sessions.find(params[:cook_session_id])

    @instruction = @cook_session.recipe.instructions.find(
      params[:instruction_id]
    )

    @messages = @cook_session.messages.order(:created_at)
  end

  def create
    @cook_session = current_user.cook_sessions.find(params[:cook_session_id])

    @message = Message.new(message_params)
    @message.cook_session = @cook_session
    @message.role = "user"

    if @message.instruction_id.present?
      @message.instruction = @cook_session.recipe.instructions.find(@message.instruction_id)
    end

    if @message.save
      @ruby_llm_chat = RubyLLM.chat

      # Fix: History must be ordered and limited to prevent token overflow
      build_conversation_history

      # Connect the tool to the chat instance
      @ruby_llm_chat = @ruby_llm_chat.with_tools(
        InstructionUpdateTool.new(recipe: @cook_session.recipe)
      )

      response = @ruby_llm_chat
        .with_instructions(instructions)
        .ask(@message.content)

      @assistant_message = Message.create!(
        role: "assistant",
        content: response.content,
        cook_session: @cook_session,
        instruction: @message.instruction
      )

      respond_to do |format|
        format.turbo_stream do
          streams = [
            turbo_stream.append("messages_list",
              partial: "messages/message",
              locals: { message: @assistant_message })
          ]


          if response.tool_calls.any? { |call| call.tool_name == "InstructionUpdateTool" }

            fresh_instruction = @message.instruction&.reload

            if fresh_instruction
              streams << turbo_stream.replace(
              "instruction_content",
              partial: "instructions/instruction_content",
              locals: { instruction: fresh_instruction }
              )
            end
          end

          render turbo_stream: streams
        end
        format.html do
          redirect_to cook_session_instruction_path(@cook_session, @message.instruction)
        end
      end
    else
      render "instructions/show", status: :unprocessable_entity
    end
  end

  private

  def build_conversation_history
    @cook_session.messages
                 .where.not(id: @message.id)
                 .order(:created_at)
                 .last(20)
                 .each do |msg|
      next if msg.content.blank?

      @ruby_llm_chat.add_message(
        role: msg.role.to_sym,
        content: msg.content
      )
    end
  end

  def cooking_context
    instruction = @message.instruction

    <<~CONTEXT
      The user is currently cooking:
      #{@cook_session.recipe.name}

      Their current instruction is:
      #{instruction&.instruction_content}

      Use this recipe and instruction as context when
      answering their questions.
    CONTEXT
  end

  def instructions
    [SYSTEM_PROMPT, cooking_context].compact.join("\n\n")
  end

  def message_params
    params.require(:message).permit(:content, :instruction_id)
  end
end
