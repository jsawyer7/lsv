require "chargebee"

class AssignFreePlanJob < ApplicationJob
  queue_as :default

  NETWORK_ERRORS = [
    defined?(ChargeBee::IOError) ? ChargeBee::IOError : nil,
    SocketError,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT,
    Net::OpenTimeout,
    Net::ReadTimeout
  ].compact.freeze

  retry_on(*NETWORK_ERRORS, wait: :polynomially_longer, attempts: 5)

  def perform(user_id)
    SidekiqRedisLock.try_lock!(user_id, ttl_seconds: 180, label: "AssignFreePlanJob") do
      run_for_user(user_id)
    end
  end

  private

  def run_for_user(user_id)
    user = User.find_by(id: user_id)
    return unless user

    Rails.logger.info("AssignFreePlanJob: started for user #{user.id} (#{user.email})")
    AssignFreePlanService.new(user: user).call
    Rails.logger.info("AssignFreePlanJob: completed for user #{user.id}")
  end
end
