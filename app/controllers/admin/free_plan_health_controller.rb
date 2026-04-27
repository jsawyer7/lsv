module Admin
  class FreePlanHealthController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin!

    def show
      window_days = params[:days].to_i
      window_days = 7 if window_days <= 0

      since_time = window_days.days.ago
      recent_users = User.where("created_at >= ?", since_time)

      users_missing_active_subscription = recent_users
        .left_joins(:chargebee_subscriptions)
        .group("users.id")
        .having("COUNT(CASE WHEN chargebee_subscriptions.status IN (?) THEN 1 END) = 0", %w[active in_trial non_renewing])
        .order(created_at: :desc)
        .limit(50)

      render json: {
        window_days: window_days,
        recent_user_count: recent_users.count,
        users_missing_active_subscription_count: users_missing_active_subscription.size,
        users_missing_active_subscription: users_missing_active_subscription.map do |user|
          {
            id: user.id,
            email: user.email,
            created_at: user.created_at
          }
        end
      }
    end

    private

    def ensure_admin!
      return if current_user&.admin?

      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
