# Get Redis URL from environment (Heroku sets REDISCLOUD_URL automatically)
redis_url = ENV.fetch('REDISCLOUD_URL', 'redis://localhost:6379/0')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  
  # Set concurrency (number of threads) - increased from default 5 to 10
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', '10').to_i
  
  # Explicitly set queues to listen to (matching ActiveJob queue_name_prefix)
  # This ensures the worker processes jobs from the correct queues
  # In production, ActiveJob uses queue_name_prefix: "literal_verification_production"
  # So jobs go to: "literal_verification_production_default"
  queue_prefix = Rails.application.config.active_job.queue_name_prefix
  
  if queue_prefix.present?
    # Production: listen to prefixed queues
    config.queues = [
      "#{queue_prefix}_default",
      "#{queue_prefix}_critical",
      "#{queue_prefix}_low",
      'default',  # Fallback for unprefixed queues
      'critical',
      'low'
    ].compact.uniq
  else
    # Development: listen to unprefixed queues
    config.queues = ['default', 'critical', 'low']
  end
  
  Rails.logger.info "Sidekiq server configured with queues: #{config.queues.inspect}"
  Rails.logger.info "ActiveJob queue_name_prefix: #{queue_prefix.inspect}"
  
  # Configure error handling
  config.death_handlers << ->(job, ex) do
    Rails.logger.error "Job #{job['class']} failed permanently: #{ex.message}"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

# Configure Sidekiq Web UI to use the same Redis connection
# This must be set before routes are loaded (in routes.rb)
# The Web UI needs explicit Redis configuration in production
require 'sidekiq/web' if defined?(Sidekiq::Web)
if defined?(Sidekiq::Web)
  # Set Redis connection for Web UI
  Sidekiq::Web.instance_variable_set(:@redis_pool, nil) # Clear any existing pool
  Sidekiq::Web.redis = { url: redis_url, size: 10 }
end

# Optional: Configure Sidekiq-Cron for scheduled jobs
if defined?(Sidekiq::Cron)
  schedule_file = Rails.root.join('config', 'sidekiq_schedule.yml')
  if File.exist?(schedule_file)
    schedule_hash = YAML.load_file(schedule_file)
    if schedule_hash.is_a?(Hash) && schedule_hash.any?
      Sidekiq::Cron::Job.load_from_hash schedule_hash
    end
  end
end

