class NotificationsController < ApplicationController
  before_action :authenticate_user!
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
end
