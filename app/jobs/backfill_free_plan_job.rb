class BackfillFreePlanJob < ApplicationJob
  queue_as :default

  def perform(limit: nil)
    scope = User
      .left_joins(:chargebee_subscriptions)
      .group("users.id")
      .having("COUNT(CASE WHEN chargebee_subscriptions.status IN (?) THEN 1 END) = 0", %w[active in_trial non_renewing])
      .order(:id)

    scope = scope.limit(limit.to_i) if limit.present? && limit.to_i > 0

    scope.find_each(batch_size: 200) do |user|
      AssignFreePlanJob.perform_later(user.id)
    end
  end
end
