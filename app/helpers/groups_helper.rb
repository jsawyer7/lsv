module GroupsHelper
  include ActionView::Helpers::NumberHelper

  def format_group_members_count(count)
    number_with_delimiter(count)
  end

  def group_member_preview_users(group, limit: 3)
    group.group_memberships.includes(:user).limit(limit).map(&:user)
  end
end
