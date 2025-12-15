class CommentPolicy < ApplicationPolicy
  def create?
    # Any authenticated user can comment on any fact or theory
    # They will be able to see their own comment even if not a peer
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

  def show?
    # Comments are only visible to peer network (handled by visible_to scope in model)
    user.present? && record.visible_to?(user)
  end
end
