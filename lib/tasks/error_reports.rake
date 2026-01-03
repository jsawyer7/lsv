namespace :errors do
  desc "Export unique errors to STDOUT (redirect to file: rake errors:unique > errors.txt)"
  task :unique => :environment do
    errors = TextContentApiLog.failed_populate_jobs
      .where.not(error_message: nil)
      .unscope(:order)
      .group(:error_message)
      .count
      .sort_by { |_, count| -count }
    
    total = errors.sum { |_, count| count }
    
    puts "="*80
    puts "UNIQUE ERRORS REPORT"
    puts "Generated: #{Time.current}"
    puts "="*80
    puts "\nTotal unique errors: #{errors.count}"
    puts "Total failed jobs: #{total}"
    puts "\n" + "="*80
    
    errors.each_with_index do |(error_msg, count), index|
      percentage = (count.to_f / total * 100).round(2)
      puts "\n#{index + 1}. #{count}x (#{percentage}%)"
      puts "#{error_msg}"
    end
  end
  
  desc "Export unique errors as CSV to STDOUT (redirect to file: rake errors:unique_csv > errors.csv)"
  task :unique_csv => :environment do
    require 'csv'
    
    errors = TextContentApiLog.failed_populate_jobs
      .where.not(error_message: nil)
      .unscope(:order)
      .group(:error_message)
      .count
      .sort_by { |_, count| -count }
    
    total = errors.sum { |_, count| count }
    
    csv_string = CSV.generate do |csv|
      csv << ['Rank', 'Count', 'Percentage', 'Error Message']
      errors.each_with_index do |(error_msg, count), index|
        percentage = (count.to_f / total * 100).round(2)
        csv << [index + 1, count, percentage, error_msg]
      end
    end
    
    puts csv_string
  end
  
  desc "Export rate limit errors"
  task :rate_limit => :environment do
    errors = TextContentApiLog.failed_populate_jobs
      .where("error_message ILIKE ?", "%rate limit%")
      .unscope(:order)
      .order(created_at: :desc)
    
    puts "="*80
    puts "RATE LIMIT ERRORS"
    puts "Total: #{errors.count}"
    puts "="*80
    
    errors.limit(100).each do |log|
      puts "\n#{log.book_code} #{log.chapter}:#{log.verse}"
      puts "  #{log.error_message}"
      puts "  Created: #{log.created_at}"
    end
  end
  
  desc "Export WFW validation errors"
  task :wfw_validation => :environment do
    errors = TextContentApiLog.failed_populate_jobs
      .where("error_message ILIKE ANY(ARRAY[?])", 
        ['%Word-for-word contains tokens%',
         '%word_for_word missing base_gloss%',
         '%WFW%',
         '%UNLICENSED_LOGIC_INSERTION%',
         '%UNCLASSIFIED_INSERTION%',
         '%TOKEN_ACCOUNTING_FAIL%',
         '%ORDER_DRIFT_FAIL%'])
      .unscope(:order)
      .order(created_at: :desc)
    
    puts "="*80
    puts "WFW VALIDATION ERRORS"
    puts "Total: #{errors.count}"
    puts "="*80
    
    errors.limit(100).each do |log|
      puts "\n#{log.book_code} #{log.chapter}:#{log.verse}"
      puts "  #{log.error_message}"
      puts "  Created: #{log.created_at}"
    end
  end
  
  desc "Export timeout errors"
  task :timeout => :environment do
    errors = TextContentApiLog.failed_populate_jobs
      .where("error_message ILIKE ANY(ARRAY[?])", 
        ['%timeout%', '%execution expired%', '%connection%'])
      .unscope(:order)
      .order(created_at: :desc)
    
    puts "="*80
    puts "TIMEOUT/CONNECTION ERRORS"
    puts "Total: #{errors.count}"
    puts "="*80
    
    errors.limit(100).each do |log|
      puts "\n#{log.book_code} #{log.chapter}:#{log.verse}"
      puts "  #{log.error_message}"
      puts "  Created: #{log.created_at}"
    end
  end
  
  desc "Export errors by category"
  task :by_category => :environment do
    def categorize_error(error_msg)
      return 'Empty' if error_msg.nil? || error_msg.strip.empty?
      msg_lower = error_msg.downcase
      
      case
      when msg_lower.include?('timeout') || msg_lower.include?('execution expired')
        'Timeout'
      when msg_lower.include?('rate limit') || msg_lower.include?('429') || msg_lower.include?('throttle')
        'Rate Limit'
      when msg_lower.include?('connection') || msg_lower.include?('network') || msg_lower.include?('ssl')
        'Network/Connection'
      when msg_lower.include?('validation') || msg_lower.include?('wfw') || msg_lower.include?('insertion')
        'Validation'
      when msg_lower.include?('unlicensed') || msg_lower.include?('unclassified')
        'WFW Policy Gate'
      when msg_lower.include?('not found') || msg_lower.include?('missing')
        'Not Found/Missing'
      when msg_lower.include?('parse') || msg_lower.include?('json')
        'Parse Error'
      when msg_lower.include?('grok api')
        'Grok API Error'
      else
        'Other'
      end
    end
    
    all_errors = TextContentApiLog.failed_populate_jobs
      .where.not(error_message: nil)
      .unscope(:order)
      .pluck(:error_message)
    
    categorized = all_errors.group_by { |msg| categorize_error(msg) }
      .transform_values { |msgs| msgs.count }
      .sort_by { |_, v| -v }
    
    puts "="*80
    puts "ERRORS BY CATEGORY"
    puts "="*80
    
    categorized.each do |category, count|
      percentage = (count.to_f / all_errors.count * 100).round(2)
      puts "\n#{category}: #{count} (#{percentage}%)"
    end
  end
  
  desc "Export error summary statistics"
  task :summary => :environment do
    total_failed = TextContentApiLog.failed_populate_jobs.count
    total_successful = TextContentApiLog.populate_jobs.successful.count
    total_with_errors = TextContentApiLog.failed_populate_jobs.where.not(error_message: nil).count
    unique_count = TextContentApiLog.failed_populate_jobs
      .where.not(error_message: nil)
      .unscope(:order)
      .distinct
      .count(:error_message)
    
    puts "="*80
    puts "ERROR SUMMARY STATISTICS"
    puts "Generated: #{Time.current}"
    puts "="*80
    puts "\nTotal failed jobs: #{total_failed}"
    puts "Total successful jobs: #{total_successful}"
    puts "Jobs with error messages: #{total_with_errors}"
    puts "Unique error types: #{unique_count}"
    
    if total_failed + total_successful > 0
      total = total_failed + total_successful
      success_rate = (total_successful.to_f / total * 100).round(2)
      puts "Success rate: #{success_rate}%"
    end
    
    puts "\n" + "="*80
    puts "TOP 10 ERRORS"
    puts "="*80
    
    errors = TextContentApiLog.failed_populate_jobs
      .where.not(error_message: nil)
      .unscope(:order)
      .group(:error_message)
      .count
      .sort_by { |_, count| -count }
      .first(10)
    
    errors.each_with_index do |(error_msg, count), index|
      percentage = (count.to_f / total_with_errors * 100).round(2)
      puts "\n#{index + 1}. #{count}x (#{percentage}%)"
      puts "   #{error_msg&.truncate(120)}"
    end
    
    puts "\n" + "="*80
    puts "ERRORS BY BOOK"
    puts "="*80
    
    TextContentApiLog.failed_populate_jobs
      .unscope(:order)
      .group(:book_code)
      .count
      .sort_by { |_, v| -v }
      .first(10)
      .each do |book, count|
        puts "#{book}: #{count}"
      end
  end
end

