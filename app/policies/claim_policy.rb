class ClaimPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end

  def index?
    true # Anyone can view the list of claims
  end

  def show?
    user.admin? || record.user_id == user.id # Users can view their own claims
  end

  def create?
    user.present? # Any logged-in user can create claims
  end

  def new?
    create?
  end

  def update?
    return true if user.admin?
    user.present? && record.user_id == user.id # Users can edit their own claims
  end

  def edit?
    update?
  end

  def destroy?
    return true if user.admin?
    user.present? && record.user_id == user.id # Users can delete their own claims
  end
end 