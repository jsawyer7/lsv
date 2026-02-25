module ApplicationHelper
  def dashboard_nav_page?
    path = request.path
    path.start_with?('/facts') ||
      path == '/all-claims' ||
      path.start_with?('/claims') ||
      path.start_with?('/theories') ||
      path.start_with?('/veritalk')
  end
end
