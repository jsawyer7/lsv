# Get Redis URL from environment (Heroku sets REDIS_URL automatically)
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  
  # Set concurrency (number of threads) - increased from default 5 to 10
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', '10').to_i
  
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

