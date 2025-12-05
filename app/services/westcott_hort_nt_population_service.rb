class WestcottHortNtPopulationService
  def initialize(source_id: 10, force_create: false, force_populate: false)
    @source_id = source_id
    @force_create = force_create
    @force_populate = force_populate
    @batch_size = ENV.fetch('BATCH_SIZE', '7').to_i
    @max_concurrent = ENV.fetch('GROK_MAX_CONCURRENT', '30').to_i
    @model = ENV.fetch('GROK_MODEL', 'grok-4-0709')
  end

  def call
    Rails.logger.info "WestcottHortNtPopulationService: Starting for source #{@source_id}"
    
    # Step 1: Find source
    source = find_source
    return { status: 'error', error: 'Source not found' } unless source

    # Step 2: Create all text content records
    creation_result = create_all_records(source)
    
    # Step 3: Populate all records
    population_result = populate_all_records(source)
    
    {
      status: 'success',
      creation: creation_result,
      population: population_result,
      completed_at: Time.current.iso8601
    }
  rescue => e
    Rails.logger.error "WestcottHortNtPopulationService failed: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { status: 'error', error: "#{e.class.name}: #{e.message}" }
  end

  private

  def find_source
    source = if @source_id
      Source.unscoped.find_by(id: @source_id.to_i)
    else
      Source.unscoped.where('name ILIKE ? OR name ILIKE ? OR name ILIKE ? OR code ILIKE ?',
                            '%Westcott%', '%Hort%', '%1881%', '%WH%').first
    end
    
    unless source
      Rails.logger.error "Westcott-Hort source not found for ID: #{@source_id}"
      return nil
    end
    
    Rails.logger.info "Found source: #{source.name} (ID: #{source.id}, Code: #{source.code})"
    source
  end

  def create_all_records(source)
    nt_book_codes = VerseCountReference::NEW_TESTAMENT_BOOKS
    total_created = 0
    total_existing = 0
    creation_errors = []

    nt_book_codes.each_with_index do |book_code, index|
      book = Book.unscoped.find_by(code: book_code)
      unless book
        Rails.logger.warn "Book #{book_code} not found, skipping..."
        next
      end

      chapters = VerseCountReference.chapters_for_book(book_code)
      next if chapters.empty?

      book_created = 0
      book_existing = 0

      chapters.each do |chapter|
        verse_count = VerseCountReference.expected_verses(book_code, chapter)
        next unless verse_count

        (1..verse_count).each do |verse|
          existing = TextContent.unscoped.find_by(
            source_id: source.id,
            book_id: book.id,
            unit_group: chapter,
            unit: verse
          )

          if existing
            book_existing += 1
            next unless @force_create
          end

          begin
            unit_key = "#{source.code}|#{book.code}|#{chapter}|#{verse}"
            text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
            language = source.language

            unless text_unit_type && language
              creation_errors << { book: book_code, chapter: chapter, verse: verse, error: "Missing text_unit_type or language" }
              next
            end

            text_content = TextContent.new(
              source: source,
              book: book,
              text_unit_type: text_unit_type,
              language: language,
              unit_group: chapter,
              unit: verse,
              unit_key: unit_key,
              content: '',
              allow_empty_content: true,
              population_status: 'pending'
            )

            if text_content.save
              book_created += 1
            else
              creation_errors << { book: book_code, chapter: chapter, verse: verse, error: text_content.errors.full_messages.join(', ') }
            end
          rescue => e
            creation_errors << { book: book_code, chapter: chapter, verse: verse, error: e.message }
          end
        end
      end

      total_created += book_created
      total_existing += book_existing
      
      Rails.logger.info "[#{index + 1}/#{nt_book_codes.count}] #{book.code}: Created: #{book_created}, Existing: #{book_existing}"
    end

    {
      total_created: total_created,
      total_existing: total_existing,
      errors: creation_errors.count,
      error_details: creation_errors.first(10)
    }
  end

  def populate_all_records(source)
    scope = TextContent.unscoped.where(source_id: source.id)
    scope = scope.where.not(population_status: 'success') unless @force_populate

    total_to_populate = scope.count
    return { status: 'skipped', message: 'No verses to populate' } if total_to_populate == 0

    Rails.logger.info "Found #{total_to_populate} verse(s) to populate"

    require 'concurrent'
    processed = 0
    success_count = 0
    error_count = 0
    start_time = Time.current

    # Use a semaphore to limit concurrent database connections
    # This prevents connection pool exhaustion when using Concurrent::Future
    max_concurrent_futures = [@batch_size, 5].min # Limit to 5 concurrent futures per batch
    semaphore = Concurrent::Semaphore.new(max_concurrent_futures)
    
    scope.find_in_batches(batch_size: @batch_size) do |batch|
      futures = batch.map do |tc|
        Concurrent::Future.execute do
          semaphore.acquire
          begin
            # Ensure we have a database connection for this thread
            ActiveRecord::Base.connection_pool.with_connection do
              service = TextContentPopulationService.new(tc)
              result = service.populate_content_fields(force: @force_populate)
              result.is_a?(Hash) && result.key?(:status) ? result : { status: 'error', error: 'Invalid result format' }
            end
          rescue => e
            Rails.logger.error "Exception in future for #{tc.unit_key}: #{e.class.name}: #{e.message}"
            { status: 'error', error: "#{e.class.name}: #{e.message}" }
          ensure
            semaphore.release
          end
        end
      end

      results = futures.map.with_index do |future, idx|
        begin
          if future.wait(300)
            result = future.value
            result.is_a?(Hash) && result.key?(:status) ? result : { status: 'error', error: 'Invalid result' }
          else
            Rails.logger.error "Future #{idx} timed out"
            { status: 'error', error: 'Timeout' }
          end
        rescue => e
          Rails.logger.error "Exception getting future #{idx}: #{e.message}"
          { status: 'error', error: e.message }
        end
      end

      batch_success = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'success' }
      batch_errors = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'error' }

      success_count += batch_success
      error_count += batch_errors
      processed += batch.size

      progress = (processed.to_f / total_to_populate * 100).round(1)
      Rails.logger.info "Progress: #{processed}/#{total_to_populate} (#{progress}%) | Success: #{batch_success}/#{batch.size} | Errors: #{batch_errors}"
    end

    elapsed = Time.current - start_time
    elapsed_minutes = (elapsed / 60.0).round(2)

    {
      total_processed: processed,
      success: success_count,
      errors: error_count,
      elapsed_minutes: elapsed_minutes
    }
  end
end

