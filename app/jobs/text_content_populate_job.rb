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
      # Deterministic validators already ran inside TextContentPopulationService.
      # At this point, content is populated and passed local validation.
      Rails.logger.info "TextContentPopulateJob: Successfully populated #{text_content.unit_key}"
    when 'provisional_ok'
      # Content populated but has validation warnings (e.g., gloss priority drift, substantival participle warnings).
      # This is acceptable in :populate mode; content is usable but may need review.
      warnings = result[:validation_warnings] || []
      flags = result[:validation_flags] || []
      Rails.logger.info "TextContentPopulateJob: Populated #{text_content.unit_key} with warnings (provisional_ok)"
      if warnings.any?
        Rails.logger.warn "TextContentPopulateJob: Warnings for #{text_content.unit_key}: #{warnings.join('; ')}"
      end
      if flags.any?
        Rails.logger.warn "TextContentPopulateJob: Validation flags for #{text_content.unit_key}: #{flags.join(', ')}"
      end
    when 'already_populated'
      # Content already exists; deterministic validation may be run separately if desired.
      Rails.logger.info "TextContentPopulateJob: Already populated #{text_content.unit_key}"
    when 'unavailable'
      Rails.logger.warn "TextContentPopulateJob: Text unavailable for #{text_content.unit_key}"
    when 'needs_repair'
      # Canonical mismatch or other deterministic validator failure that is repairable.
      # Do not retry endlessly; leave in needs_repair state for manual or targeted repair job.
      Rails.logger.warn "TextContentPopulateJob: Needs repair for #{text_content.unit_key}: #{result[:error]}"
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

