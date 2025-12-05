class TextContentPopulateJob < ApplicationJob
  queue_as :default

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(text_content_id, force: false)
    text_content = TextContent.unscoped.find_by(id: text_content_id)
    
    unless text_content
      Rails.logger.error "TextContentPopulateJob: TextContent not found with id: #{text_content_id}"
      return
    end

    Rails.logger.info "TextContentPopulateJob: Processing #{text_content.unit_key} (force: #{force})"

    service = TextContentPopulationService.new(text_content)
    result = service.populate_content_fields(force: force)

    case result[:status]
    when 'success'
      Rails.logger.info "TextContentPopulateJob: Successfully populated #{text_content.unit_key}"
    when 'already_populated'
      Rails.logger.info "TextContentPopulateJob: Already populated #{text_content.unit_key}"
    when 'unavailable'
      Rails.logger.warn "TextContentPopulateJob: Text unavailable for #{text_content.unit_key}"
    when 'error'
      Rails.logger.error "TextContentPopulateJob: Error populating #{text_content.unit_key}: #{result[:error]}"
      raise "Population failed: #{result[:error]}" # This will trigger retry
    else
      Rails.logger.error "TextContentPopulateJob: Unknown status for #{text_content.unit_key}: #{result[:status]}"
      raise "Unknown status: #{result[:status]}"
    end

    result
  rescue => e
    Rails.logger.error "TextContentPopulateJob: Exception processing #{text_content_id}: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Update status if we have the record
    if text_content
      text_content.update_columns(
        population_status: 'error',
        population_error_message: "#{e.class.name}: #{e.message}".truncate(1000)
      )
    end
    
    raise # Re-raise to trigger retry mechanism
  end
end

