Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # Set concurrency (number of threads) - increased from default 5 to 10
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', '10').to_i
  
  # Configure error handling
  config.death_handlers << ->(job, ex) do
    Rails.logger.error "Job #{job['class']} failed permanently: #{ex.message}"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
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

