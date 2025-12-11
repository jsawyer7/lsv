class PopulateSeptuagintLxxJob < ApplicationJob
  queue_as :default

  # Retry up to 3 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(source_id = nil, force_create: false, force_populate: false)
    # Find or create Septuagint Swete source
    source = find_or_create_source(source_id)
    unless source
      Rails.logger.error "PopulateSeptuagintLxxJob: Source not found or could not be created"
      return { status: 'error', error: 'Source not found or could not be created' }
    end

    # Idempotency check: Only run once unless forced
    cache_key = "lxx_population_completed_#{source.id}"
    
    # Check database for completion status (more reliable than cache)
    total_verses = TextContent.unscoped.where(source_id: source.id).count
    success_verses = TextContent.unscoped.where(source_id: source.id, population_status: 'success').count
    
    # Consider completed if 100% are successful (strict requirement for 100% accuracy)
    completion_rate = total_verses > 0 ? (success_verses.to_f / total_verses * 100) : 0
    
    # Only consider complete if ALL verses are successful (100% completion required)
    if success_verses == total_verses && total_verses > 0 && !force_populate
      Rails.logger.info "PopulateSeptuagintLxxJob: Already completed for source #{source.id} (#{completion_rate.round(1)}% success). Use force_populate: true to rerun."
      Rails.cache.write(cache_key, true, expires_in: 1.year)
      return { 
        status: 'already_completed', 
        message: "Population already completed (#{completion_rate.round(1)}% success)",
        completion_rate: completion_rate,
        total_verses: total_verses,
        success_verses: success_verses
      }
    end
    
    # Also check cache as secondary check
    if Rails.cache.read(cache_key) && !force_populate
      Rails.logger.info "PopulateSeptuagintLxxJob: Already marked as completed in cache for source #{source.id}. Use force_populate: true to rerun."
      return { 
        status: 'already_completed', 
        message: 'Population already completed (cached)',
        completed_at: Rails.cache.read("lxx_population_completed_at_#{source.id}")
      }
    end

    Rails.logger.info "PopulateSeptuagintLxxJob: Starting orchestration for source #{source.id}"
    Rails.cache.write('lxx_population_attempted', true, expires_in: 1.year)
    Rails.cache.delete('lxx_population_error')

    # Step 1: Create all text content records (if needed)
    if force_create || TextContent.unscoped.where(source_id: source.id).count == 0
      Rails.logger.info "Creating text content records..."
      creation_result = create_all_records(source, force: force_create)
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
    error_msg = "PopulateSeptuagintLxxJob exception: #{e.class.name}: #{e.message}"
    Rails.logger.error error_msg
    Rails.logger.error e.backtrace.join("\n")
    Rails.cache.write('lxx_population_error', error_msg, expires_in: 1.year)
    raise # Re-raise to trigger retry mechanism
  end

  private

  def find_or_create_source(source_id)
    source = if source_id
      Source.unscoped.find_by(id: source_id.to_i)
    else
      # Try to find by name variations
      Source.unscoped.where('name ILIKE ? OR name ILIKE ? OR name ILIKE ? OR code ILIKE ?',
                            '%Swete%', '%Septuagint%', '%LXX%', '%SWETE%').first
    end

    unless source
      # Create the source if it doesn't exist
      language = Language.unscoped.find_by(code: 'grc')
      unless language
        Rails.logger.error "PopulateSeptuagintLxxJob: Greek language not found"
        return nil
      end

      source = Source.create!(
        code: 'LXX_SWETE',
        name: 'Septuagint (H.B. Swete 1894–1909)',
        description: 'The Old Testament in Greek according to the Septuagint, edited by H.B. Swete',
        language: language
      )
      Rails.logger.info "PopulateSeptuagintLxxJob: Created new source: #{source.name} (ID: #{source.id})"
    end

    source
  end

  def create_all_records(source, force: false)
    ot_book_codes = VerseCountReference::OLD_TESTAMENT_BOOKS
    total_created = 0
    total_existing = 0

    ot_book_codes.each_with_index do |book_code, index|
      book = Book.unscoped.find_by(code: book_code)
      unless book
        Rails.logger.warn "Book not found: #{book_code}"
        next
      end

      chapters = VerseCountReference.chapters_for_book(book_code)
      if chapters.empty?
        Rails.logger.warn "No chapters found for #{book_code}"
        next
      end

      book_created = 0
      book_existing = 0

      chapters.each do |chapter_num|
        verse_count = VerseCountReference.expected_verses(book_code, chapter_num)
        next unless verse_count

        (1..verse_count).each do |verse_num|
          existing = TextContent.unscoped.find_by(
            source_id: source.id,
            book_id: book.id,
            unit_group: chapter_num,
            unit: verse_num
          )

          if existing
            book_existing += 1
            next unless force
          end

          begin
            unit_key = "#{source.code}|#{book.code}|#{chapter_num}|#{verse_num}"
            text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
            language = source.language

            unless text_unit_type && language
              Rails.logger.error "Missing text_unit_type or language for #{book.code} #{chapter_num}:#{verse_num}"
              next
            end

            text_content = TextContent.new(
              source: source,
              book: book,
              text_unit_type: text_unit_type,
              language: language,
              unit_group: chapter_num,
              unit: verse_num,
              unit_key: unit_key,
              content: '',
              allow_empty_content: true,
              population_status: 'pending'
            )

            if text_content.save
              book_created += 1
            else
              Rails.logger.error "Error creating #{book.code} #{chapter_num}:#{verse_num}: #{text_content.errors.full_messages.join(', ')}"
            end
          rescue => e
            Rails.logger.error "Exception creating #{book.code} #{chapter_num}:#{verse_num}: #{e.message}"
          end
        end
      end

      total_created += book_created
      total_existing += book_existing

      if (index + 1) % 5 == 0 || book_created > 0
        Rails.logger.info "[#{index + 1}/#{ot_book_codes.count}] #{book.code}: Created: #{book_created}, Existing: #{book_existing}"
      end
    end

    {
      total_created: total_created,
      total_existing: total_existing
    }
  end

end

