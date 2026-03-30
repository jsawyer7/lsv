class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def display_message
    message.presence || default_message
  end

  def default_message
    case key
    when 'post_created', 'claim_created'
      actor_name = actor&.full_name.presence || actor&.email || 'Someone'
      content = notifiable.respond_to?(:content) ? notifiable.content : ''
      "#{actor_name} Posted: #{content.truncate(120)}"
    when 'password_changed'
      'Password Changed. You have changed your old password to a new password. Your password has been changed successfully.'
    when 'fact_liked'
      actor_name = actor&.full_name.presence || actor&.email || 'Someone'
      "#{actor_name} liked your fact."
    when 'theory_liked'
      actor_name = actor&.full_name.presence || actor&.email || 'Someone'
      "#{actor_name} liked your theory."
    when 'peer_request'
      actor_name = actor&.full_name.presence || actor&.email || 'Someone'
      "#{actor_name} sent you a peer request."
    else
      message.to_s
    end
  end
end
