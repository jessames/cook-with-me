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
  PROMPT

  def create
    @cook_session = current_user.cook_sessions.find(params[:cook_session_id])

    @message = Message.new(message_params)
    @message.cook_session = @cook_session
    @message.role = "user"

    if @message.save
      @ruby_llm_chat = RubyLLM.chat

      build_conversation_history

      # @ruby_llm_chat.with_tool(TripItemsTool.new(trip_id:@chat.trip.id))
      # @ruby_llm_chat.with_tool(WeatherTool.new)

      response = @ruby_llm_chat
        .with_instructions(instructions)
        .ask(@message.content)

      @assistant_message = Message.create(
        role: "assistant",
        content: response.content,
        cook_session: @cook_session,
        instruction: @message.instruction
      )

      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to cook_session_instruction_path(
            @cook_session,
            @message.instruction
          )
        end
      end

    else
      render "instructions/show",
             status: :unprocessable_entity
    end
  end

  def build_conversation_history
    @cook_session.messages.where.not(id: @message.id).each do |message|
      next if message.content.blank?

      @ruby_llm_chat.add_message(message)
    end
  end

  private

  def cooking_context
    instruction = @message.instruction

    <<~CONTEXT
      The user is currently cooking:
      #{@cook_session.recipe.name}

      Their current instruction is:
      #{instruction&.content}

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
