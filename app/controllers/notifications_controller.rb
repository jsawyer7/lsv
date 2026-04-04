class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:accept_group_invite, :reject_group_invite]
  layout 'dashboard'

  def index
    current_user.notifications.unread.update_all(read_at: Time.current)

    @filter = params[:filter].presence || 'all'
    @notifications = current_user.notifications.recent_first

    case @filter
    when 'new'
      @notifications = @notifications.where('created_at >= ?', 24.hours.ago)
    when 'unread'
      @notifications = @notifications.unread
    end

    @notifications = @notifications.includes(:actor).limit(100)
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back(fallback_location: notifications_path)
  end

  def accept_group_invite
    group = @notification&.notifiable
    return handle_group_invite_response('Group invite not found.', :not_found) unless valid_group_invite_notification?(group)

    if group.member?(current_user)
      message = 'You already joined this group.'
    else
      group.group_memberships.create!(user: current_user)
      message = 'Group invite accepted. You joined the group.'
    end

    @notification.update(read_at: Time.current)
    handle_group_invite_response(message, :ok)
  end

  def reject_group_invite
    group = @notification&.notifiable
    return handle_group_invite_response('Group invite not found.', :not_found) unless valid_group_invite_notification?(group)

    @notification.update(read_at: Time.current)
    handle_group_invite_response('Group invite declined.', :ok)
  end

  private

  def set_notification
    @notification = current_user.notifications.find_by(id: params[:id])
  end

  def valid_group_invite_notification?(group)
    @notification.present? && @notification.key == 'group_invite' && group.is_a?(Group)
  end

  def handle_group_invite_response(message, status)
    respond_to do |format|
      format.html do
        redirect_back(
          fallback_location: notifications_path,
          notice: (status == :ok ? message : nil),
          alert: (status == :ok ? nil : message)
        )
      end
      format.json do
        render json: {
          ok: status == :ok,
          message: message,
          notification_id: params[:notification_dropdown_anchor].presence || @notification&.id
        }, status: status
      end
    end
  end
end
