class PopulateWestcottHortNtJob < ApplicationJob
  queue_as :default

  # Retry up to 3 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(source_id = 10, force_create: false, force_populate: false)
    # Idempotency check: Only run once unless forced
    cache_key = "wh_nt_population_completed_#{source_id}"
    
    # Check database for completion status (more reliable than cache)
    source = Source.unscoped.find_by(id: source_id.to_i)
    unless source
      Rails.logger.error "PopulateWestcottHortNtJob: Source not found: #{source_id}"
      return { status: 'error', error: 'Source not found' }
    end

    if source
      total_verses = TextContent.unscoped.where(source_id: source.id).count
      success_verses = TextContent.unscoped.where(source_id: source.id, population_status: 'success').count
      
      # Consider completed if 100% are successful (strict requirement for 100% accuracy)
      completion_rate = total_verses > 0 ? (success_verses.to_f / total_verses * 100) : 0
      
      # Only consider complete if ALL verses are successful (100% completion required)
      if success_verses == total_verses && total_verses > 0 && !force_populate
        Rails.logger.info "PopulateWestcottHortNtJob: Already completed for source #{source_id} (#{completion_rate.round(1)}% success). Use force_populate: true to rerun."
        Rails.cache.write(cache_key, true, expires_in: 1.year)
        return { 
          status: 'already_completed', 
          message: "Population already completed (#{completion_rate.round(1)}% success)",
          completion_rate: completion_rate,
          total_verses: total_verses,
          success_verses: success_verses
        }
      end
    end
    
    # Also check cache as secondary check
    if Rails.cache.read(cache_key) && !force_populate
      Rails.logger.info "PopulateWestcottHortNtJob: Already marked as completed in cache for source #{source_id}. Use force_populate: true to rerun."
      return { 
        status: 'already_completed', 
        message: 'Population already completed (cached)',
        completed_at: Rails.cache.read("wh_nt_population_completed_at_#{source_id}")
      }
    end

    Rails.logger.info "PopulateWestcottHortNtJob: Starting orchestration for source #{source_id}"
    Rails.cache.write('wh_nt_population_attempted', true, expires_in: 1.year)
    Rails.cache.delete('wh_nt_population_error')

    # Step 1: Create all text content records (if needed)
    if force_create || TextContent.unscoped.where(source_id: source.id).count == 0
      Rails.logger.info "Creating text content records..."
      creation_result = create_all_records(source)
      Rails.logger.info "Created: #{creation_result[:total_created]}, Existing: #{creation_result[:total_existing]}"
    end

    # Step 2: Enqueue individual jobs for each verse that needs population
    scope = TextContent.unscoped.where(source_id: source.id)
    scope = scope.where.not(population_status: 'success') unless force_populate

    total_to_populate = scope.count
    if total_to_populate == 0
      Rails.logger.info "No verses to populate"
      return { status: 'skipped', message: 'No verses to populate' }
    end

    Rails.logger.info "Enqueuing #{total_to_populate} individual verse population jobs..."

    enqueued_count = 0
    scope.find_each(batch_size: 100) do |tc|
      TextContentPopulateJob.perform_later(tc.id, force: force_populate)
      enqueued_count += 1
      
      # Log progress every 100 jobs
      if enqueued_count % 100 == 0
        Rails.logger.info "Enqueued #{enqueued_count}/#{total_to_populate} jobs..."
      end
    end

    Rails.logger.info "Successfully enqueued #{enqueued_count} verse population jobs"
    
    {
      status: 'jobs_enqueued',
      message: "Enqueued #{enqueued_count} verse population jobs",
      enqueued_count: enqueued_count,
      total_verses: total_to_populate
    }
  rescue => e
    error_msg = "PopulateWestcottHortNtJob exception: #{e.class.name}: #{e.message}"
    Rails.logger.error error_msg
    Rails.logger.error e.backtrace.join("\n")
    Rails.cache.write('wh_nt_population_error', error_msg, expires_in: 1.year)
    raise # Re-raise to trigger retry mechanism
  end

  private

  def create_all_records(source)
    nt_book_codes = VerseCountReference::NEW_TESTAMENT_BOOKS
    total_created = 0
    total_existing = 0

    nt_book_codes.each do |book_code|
      book = Book.unscoped.find_by(code: book_code)
      unless book
        Rails.logger.warn "Book not found: #{book_code}"
        next
      end

      chapters = VerseCountReference.book_chapter_counts[book_code.to_s.upcase]
      next unless chapters

      chapters.each do |chapter_num, verse_count|
        (1..verse_count).each do |verse_num|
          existing = TextContent.unscoped.find_by(
            source_id: source.id,
            book_id: book.id,
            unit_group: chapter_num,
            unit: verse_num
          )

          if existing
            total_existing += 1
            next
          end

          begin
            service = TextContentCreationService.new(
              source_name: source.id.to_s,
              current_book_code: book.code,
              current_chapter: chapter_num,
              current_verse: verse_num
            )
            result = service.create_next_record_if_not_exists
            
            case result[:status]
            when 'created'
              total_created += 1
            when 'exists'
              total_existing += 1
            when 'error'
              Rails.logger.error "Error creating #{book.code} #{chapter_num}:#{verse_num}: #{result[:error]}"
            end
          rescue => e
            Rails.logger.error "Exception creating #{book.code} #{chapter_num}:#{verse_num}: #{e.message}"
          end
        end
      end
    end

    {
      total_created: total_created,
      total_existing: total_existing
    }
  end
end
