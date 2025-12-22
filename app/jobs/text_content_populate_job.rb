class TextContentPopulateJob < ApplicationJob
  queue_as :default

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(text_content_id, force: false)
    @force = force
    text_content = TextContent.unscoped.find_by(id: text_content_id)
    
    unless text_content
      Rails.logger.error "TextContentPopulateJob: TextContent not found with id: #{text_content_id}"
      log_job_failure(text_content_id, nil, "TextContent not found with id: #{text_content_id}")
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
      log_job_success(text_content, result)
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
      log_job_success(text_content, result, status: 'provisional_ok', warnings: warnings, flags: flags)
    when 'already_populated'
      # Content already exists; deterministic validation may be run separately if desired.
      Rails.logger.info "TextContentPopulateJob: Already populated #{text_content.unit_key}"
      log_job_success(text_content, result, status: 'already_populated')
    when 'unavailable'
      Rails.logger.warn "TextContentPopulateJob: Text unavailable for #{text_content.unit_key}"
      log_job_failure(text_content, result, "Text unavailable in source edition", status: 'unavailable')
    when 'needs_repair'
      # Canonical mismatch or other deterministic validator failure that is repairable.
      # Do not retry endlessly; leave in needs_repair state for manual or targeted repair job.
      Rails.logger.warn "TextContentPopulateJob: Needs repair for #{text_content.unit_key}: #{result[:error]}"
      log_job_failure(text_content, result, result[:error], status: 'needs_repair')
    when 'error'
      error_msg = result[:error] || 'Unknown error'
      Rails.logger.error "TextContentPopulateJob: Error populating #{text_content.unit_key}: #{error_msg}"
      log_job_failure(text_content, result, error_msg, status: 'error')
      raise "Population failed: #{error_msg}" # This will trigger retry
    else
      error_msg = "Unknown status: #{result[:status]}"
      Rails.logger.error "TextContentPopulateJob: Unknown status for #{text_content.unit_key}: #{result[:status]}"
      log_job_failure(text_content, result, error_msg, status: 'error')
      raise error_msg
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
      
      # Log the failure
      log_job_failure(text_content, nil, "#{e.class.name}: #{e.message}", exception: e)
    else
      log_job_failure(text_content_id, nil, "#{e.class.name}: #{e.message}", exception: e)
    end
    
    raise # Re-raise to trigger retry mechanism
  end

  private

  def log_job_success(text_content, result, status: 'success', warnings: nil, flags: nil)
    return unless text_content

    TextContentApiLog.create!(
      text_content_id: text_content.id,
      source_name: text_content.source&.name || 'Unknown',
      book_code: text_content.book&.code || 'Unknown',
      chapter: text_content.unit_group,
      verse: text_content.unit,
      action: 'populate_job',
      request_payload: {
        text_content_id: text_content.id,
        unit_key: text_content.unit_key,
        force: @force || false
      }.to_json,
      response_payload: {
        status: status,
        source_text: result[:source_text],
        word_for_word_count: result[:word_for_word]&.count || 0,
        lsv_literal_reconstruction: result[:lsv_literal_reconstruction],
        validation_warnings: warnings,
        validation_flags: flags,
        ai_notes: result[:ai_notes]
      }.to_json,
      status: status,
      ai_model_name: result[:ai_model_name] || ENV.fetch('GROK_MODEL', 'grok-4-0709')
    )
  rescue => e
    Rails.logger.error "Failed to log job success: #{e.message}"
  end

  def log_job_failure(text_content_or_id, result, error_message, status: 'error', exception: nil)
    # Handle both text_content object and text_content_id
    if text_content_or_id.is_a?(TextContent)
      text_content = text_content_or_id
      text_content_id = text_content.id
    else
      text_content = TextContent.unscoped.find_by(id: text_content_or_id) if text_content_or_id
      text_content_id = text_content_or_id
    end

    payload = {
      text_content_id: text_content_id,
      error: error_message,
      status: status
    }
    
    if text_content
      payload[:unit_key] = text_content.unit_key
      payload[:source] = text_content.source&.name
      payload[:book] = text_content.book&.std_name
      payload[:chapter] = text_content.unit_group
      payload[:verse] = text_content.unit
    end
    
    if exception
      payload[:exception_class] = exception.class.name
      payload[:backtrace] = exception.backtrace&.first(5)
    end

    if result
      payload[:result_status] = result[:status]
      payload[:result_error] = result[:error]
    end

    TextContentApiLog.create!(
      text_content_id: text_content_id,
      source_name: text_content&.source&.name || 'Unknown',
      book_code: text_content&.book&.code || 'Unknown',
      chapter: text_content&.unit_group,
      verse: text_content&.unit,
      action: 'populate_job',
      request_payload: payload.to_json,
      response_payload: result ? result.to_json : nil,
      status: status,
      error_message: error_message.truncate(2000),
      ai_model_name: result&.dig(:ai_model_name) || ENV.fetch('GROK_MODEL', 'grok-4-0709')
    )
  rescue => e
    Rails.logger.error "Failed to log job failure: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
  end
end

