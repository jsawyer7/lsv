class LikePolicy < ApplicationPolicy
  def create?
    # All authenticated users can like any Fact, Theory, or Comment
    user.present?
  end

  def destroy?
    # Users can only unlike their own likes
    user.present? && record.user_id == user.id
  end
end
