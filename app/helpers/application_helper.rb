module ApplicationHelper
  def unread_notifications_count
    return 0 unless user_signed_in?
    current_user.notifications.unread.count
  end

  def navbar_notifications(limit = 4)
    return Notification.none unless user_signed_in?
    current_user.notifications.recent_first.includes(:actor, :notifiable).limit(limit)
  end

  def dashboard_nav_page?
    path = request.path
    path.start_with?('/facts') ||
      path == '/all-claims' ||
      path.start_with?('/claims') ||
      path.start_with?('/theories') ||
      path.start_with?('/peers') ||
      path.match?(%r{/users/\d+/profile}) ||
      path.start_with?('/veritalk') ||
      path.start_with?('/settings')
  end
end
