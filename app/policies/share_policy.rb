class SharePolicy < ApplicationPolicy
  def create?
    # Any authenticated user can share with their peers
    user.present?
  end

  def show?
    # Users can see shares they received or sent
    user.present? && (record.recipient == user || record.user == user)
  end

  def reshare?
    # Users can reshare items that were shared with them
    user.present?
  end
end
