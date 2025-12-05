namespace :sidekiq do
  desc "Clear Sidekiq statistics (processed, failed counts). Usage: rake sidekiq:clear_stats"
  task clear_stats: :environment do
    require 'sidekiq/api'
    
    puts "=" * 80
    puts "Clearing Sidekiq Statistics"
    puts "=" * 80
    puts ""
    
    # Get current stats
    stats = Sidekiq::Stats.new
    puts "Current stats:"
    puts "  Processed: #{stats.processed}"
    puts "  Failed: #{stats.failed}"
    puts ""
    
    # Clear stats
    Sidekiq::Stats.new.reset
    
    # Verify
    new_stats = Sidekiq::Stats.new
    puts "After reset:"
    puts "  Processed: #{new_stats.processed}"
    puts "  Failed: #{new_stats.failed}"
    puts ""
    puts "✓ Sidekiq statistics cleared successfully"
  end
  
  desc "Show Sidekiq statistics. Usage: rake sidekiq:stats"
  task stats: :environment do
    require 'sidekiq/api'
    
    stats = Sidekiq::Stats.new
    
    puts "=" * 80
    puts "Sidekiq Statistics"
    puts "=" * 80
    puts ""
    puts "Processed: #{stats.processed}"
    puts "Failed: #{stats.failed}"
    puts "Busy: #{stats.busy}"
    puts "Enqueued: #{stats.enqueued}"
    puts "Retries: #{stats.retry_size}"
    puts "Scheduled: #{stats.scheduled_size}"
    puts "Dead: #{stats.dead_size}"
    puts ""
    puts "Processes: #{stats.processes_size}"
    puts "Workers: #{stats.workers_size}"
    puts ""
  end
end

