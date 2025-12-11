class PopulateSeptuagintLxxJob < ApplicationJob
  queue_as :default

  # Retry up to 3 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Known sub-verse splits in Swete 1894 (verse has a/b/c sub-verses)
  # Format: { book_code => { chapter => { base_verse => ['a', 'b', 'c'] } } }
  # Example: Job 42:17 has sub-verses 17a and 17b
  SWETE_SUBVERSE_SPLITS = {
    'JOB' => {
      42 => {
        17 => ['a', 'b']  # Job 42:17a and 42:17b
      }
    }
    # Add more as discovered:
    # 'PSA' => { ... },
    # 'PRO' => { ... },
    # etc.
  }.freeze

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
    # Also include verses that failed fidelity check
    scope = TextContent.unscoped.where(source_id: source.id)
    
    unless force_populate
      # Include verses that need population OR failed fidelity
      scope = scope.where(
        "(population_status != 'success' OR population_status IS NULL) OR " \
        "(population_status = 'success' AND population_error_message LIKE '%fidelity%')"
      )
    end

    total_to_populate = scope.count
    if total_to_populate == 0
      Rails.logger.info "No verses to populate"
      return { status: 'skipped', message: 'No verses to populate' }
    end

    Rails.logger.info "Enqueuing #{total_to_populate} individual verse population jobs (includes fidelity retries)..."

    enqueued_count = 0
    fidelity_retries = 0
    
    scope.find_each(batch_size: 100) do |tc|
      # Force retry if it's a fidelity error
      force_retry = tc.population_error_message&.include?('fidelity') || force_populate
      
      TextContentPopulateJob.perform_later(tc.id, force: force_retry)
      enqueued_count += 1
      fidelity_retries += 1 if force_retry && tc.population_status == 'success'
      
      # Log progress every 100 jobs
      if enqueued_count % 100 == 0
        Rails.logger.info "Enqueued #{enqueued_count}/#{total_to_populate} jobs... (#{fidelity_retries} fidelity retries)"
      end
    end

    Rails.logger.info "Successfully enqueued #{enqueued_count} verse population jobs (#{fidelity_retries} fidelity retries)"
    
    {
      status: 'jobs_enqueued',
      message: "Enqueued #{enqueued_count} verse population jobs (#{fidelity_retries} fidelity retries)",
      enqueued_count: enqueued_count,
      fidelity_retries: fidelity_retries,
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
          # Check if this verse has sub-verses in Swete
          sub_verses = get_sub_verses(book.code, chapter_num, verse_num)
          
          if sub_verses.any?
            # Create separate records for each sub-verse (e.g., 17a, 17b, 17c)
            sub_verses.each do |sub_verse|
              verse_identifier = "#{verse_num}#{sub_verse}"
              created, existing = create_verse_record(source, book, chapter_num, verse_identifier, force)
              book_created += created
              book_existing += existing
            end
          else
            # Create single record for regular verse
            created, existing = create_verse_record(source, book, chapter_num, verse_num.to_s, force)
            book_created += created
            book_existing += existing
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

  private

  def get_sub_verses(book_code, chapter, verse)
    book_splits = SWETE_SUBVERSE_SPLITS[book_code]
    return [] unless book_splits

    chapter_splits = book_splits[chapter]
    return [] unless chapter_splits

    chapter_splits[verse] || []
  end

  def create_verse_record(source, book, chapter_num, verse_identifier, force)
    created = 0
    existing = 0

    record = TextContent.unscoped.find_by(
      source_id: source.id,
      book_id: book.id,
      unit_group: chapter_num,
      unit: verse_identifier.to_s
    )

    if record
      existing = 1
      return [created, existing] unless force
    end

    begin
      unit_key = "#{source.code}|#{book.code}|#{chapter_num}|#{verse_identifier}"
      text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
      language = source.language

      unless text_unit_type && language
        Rails.logger.error "Missing text_unit_type or language for #{book.code} #{chapter_num}:#{verse_identifier}"
        return [created, existing]
      end

      text_content = TextContent.new(
        source: source,
        book: book,
        text_unit_type: text_unit_type,
        language: language,
        unit_group: chapter_num,
        unit: verse_identifier.to_s,
        unit_key: unit_key,
        content: '',
        allow_empty_content: true,
        population_status: 'pending'
      )

      if text_content.save
        created = 1
      else
        Rails.logger.error "Error creating #{book.code} #{chapter_num}:#{verse_identifier}: #{text_content.errors.full_messages.join(', ')}"
      end
    rescue => e
      Rails.logger.error "Exception creating #{book.code} #{chapter_num}:#{verse_identifier}: #{e.message}"
    end

    [created, existing]
  end

end

