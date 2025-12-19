class VeritalkController < ApplicationController
  include ActionController::Live

  before_action :authenticate_user!

  def chat
    response.headers['Content-Type'] = 'text/event-stream'

    conversation = find_or_create_conversation
    response.headers['X-Veritalk-Conversation-Id'] = conversation.id.to_s

    user_message_text = params[:message].to_s

    service = VeritalkChatService.new(
      user: current_user,
      conversation: conversation,
      user_message_text: user_message_text
    )

    service.stream(response)
  rescue => e
    Rails.logger.error "VeriTalk controller error: #{e.message}"
    begin
      response.stream.write("Sorry, VeriTalk had a problem handling your request.")
    rescue StandardError
      # ignore write errors during failure handling
    end
  ensure
    response.stream.close
  end

  def messages
    conversation = current_user.conversations.find_by(id: params[:id])

    unless conversation
      render json: { error: 'Conversation not found' }, status: :not_found
      return
    end

    messages = conversation.conversation_messages.order(position: :asc).map do |msg|
      {
        id: msg.id,
        role: msg.role,
        content: msg.content,
        position: msg.position,
        created_at: msg.created_at
      }
    end

    render json: {
      conversation_id: conversation.id,
      topic: conversation.topic,
      messages: messages
    }
  end

  def latest_conversation
    conversation = current_user.conversations.order(updated_at: :desc).first

    if conversation
      render json: { conversation_id: conversation.id }
    else
      render json: { conversation_id: nil }
    end
  end

  def conversations_list
    conversations = current_user.conversations.order(updated_at: :desc).limit(50).map do |conv|
      {
        id: conv.id,
        topic: conv.topic,
        message_count: conv.conversation_messages.count,
        updated_at: conv.updated_at,
        created_at: conv.created_at
      }
    end

    render json: { conversations: conversations }
  end

  private

  def find_or_create_conversation
    if params[:conversation_id].present?
      current_user.conversations.find_by(id: params[:conversation_id]) || create_new_conversation
    else
      create_new_conversation
    end
  end

  def create_new_conversation
    # Topic will be auto-generated from the first message by the service
    current_user.conversations.create!(topic: "VeriTalk conversation")
  end
end
