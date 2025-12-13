class CommentPolicy < ApplicationPolicy
  def create?
    # All authenticated users can comment on any Fact, Theory, or Comment
    user.present?
  end

  def destroy?
    # Users can only delete their own comments
    user.present? && record.user_id == user.id
  end

  def update?
    # Users can only edit their own comments
    user.present? && record.user_id == user.id
  end
end
