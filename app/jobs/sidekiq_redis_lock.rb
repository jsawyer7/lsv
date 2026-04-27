
module SidekiqRedisLock
  LOCK_PREFIX = "lock:assign_free_plan:user:"

  def self.try_lock!(resource_id, ttl_seconds: 120, label: "job")
    return yield if skip_lock?

    key = "#{LOCK_PREFIX}#{resource_id}"
    token = SecureRandom.hex(16)
    acquired =
      Sidekiq.redis do |conn|
        conn.set(key, token, nx: true, ex: ttl_seconds.to_i)
      end

    unless acquired
      Rails.logger.info("#{label}: lock busy for resource #{resource_id}, skipping")
      return
    end

    begin
      yield
    ensure
      Sidekiq.redis do |conn|
        current = conn.get(key)
        conn.del(key) if current == token
      end
    end
  end

  def self.skip_lock?
    !defined?(Sidekiq) || !Sidekiq.respond_to?(:redis)
  rescue StandardError
    true
  end
end
