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
