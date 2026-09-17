# Clears classification and translation reconstruction fields on text_contents:
# addressed/responsible party (+ custom names), genre, LSV literal reconstruction,
# and word-for-word JSON.
class ClearPartyAndGenreMetadataService
  STRING_FIELDS = %i[
    addressed_party_code
    addressed_party_custom_name
    responsible_party_code
    responsible_party_custom_name
    genre_code
    lsv_literal_reconstruction
  ].freeze

  JSON_FIELDS = {
    word_for_word_translation: []
  }.freeze

  FIELDS = (STRING_FIELDS + JSON_FIELDS.keys).freeze

  class ScopeError < StandardError; end

  def initialize(source_id: nil, book_code: nil, all: false, dry_run: true)
    @source_id = source_id
    @book_code = book_code
    @all = all
    @dry_run = dry_run
    @source = nil
    @book = nil
  end

  def call
    scope = resolve_scope
    before = field_counts(scope)
    populated_scope = records_with_data(scope)
    populated_count = populated_scope.count

    cleared_count = 0
    unless @dry_run
      cleared_count = populated_scope.update_all(clear_attributes)
    end

    after = field_counts(scope)

    {
      dry_run: @dry_run,
      total_records: scope.count,
      records_with_data: populated_count,
      cleared_count: cleared_count,
      would_clear: @dry_run ? populated_count : 0,
      before: before,
      after: after,
      verified: after.values.all?(&:zero?),
      source: @source,
      book: @book
    }
  end

  def verify
    scope = resolve_scope
    remaining = field_counts(scope)
    remaining_records = records_with_data(scope)

    {
      total_records: scope.count,
      remaining: remaining,
      remaining_record_count: remaining_records.count,
      cleared: remaining.values.all?(&:zero?),
      sample_remaining: remaining_records.limit(10).map { |tc| remaining_record_summary(tc) }
    }
  end

  private

  def resolve_scope
    base = TextContent.unscoped

    if @all
      return base
    end

    if @source_id.blank? && @book_code.blank?
      raise ScopeError, "Provide source_id and book_code, or set all: true"
    end

    if @source_id.present?
      @source = Source.unscoped.find_by(id: @source_id.to_i)
      raise ScopeError, "Source not found: #{@source_id}" unless @source
      base = base.where(source_id: @source.id)
    end

    if @book_code.present?
      @book = Book.unscoped.find_by(code: @book_code) ||
              Book.unscoped.where('LOWER(code) = LOWER(?)', @book_code).first
      raise ScopeError, "Book not found: #{@book_code}" unless @book
      base = base.where(book_id: @book.id)
    end

    base
  end

  def records_with_data(scope)
    table = TextContent.arel_table
    string_condition = STRING_FIELDS.map do |field|
      table[field].not_eq(nil).and(table[field].not_eq(''))
    end.reduce(:or)

    # word_for_word_translation defaults to []; treat empty arrays as cleared
    json_sql = JSON_FIELDS.keys.map do |field|
      "(#{field} IS NOT NULL AND COALESCE(#{field}::text, '[]') != '[]')"
    end.join(' OR ')

    if string_condition && json_sql.present?
      scope.where(string_condition).or(scope.where(json_sql))
    elsif string_condition
      scope.where(string_condition)
    else
      scope.where(json_sql)
    end
  end

  def field_counts(scope)
    counts = STRING_FIELDS.index_with do |field|
      scope.where.not(field => [nil, '']).count
    end

    JSON_FIELDS.each_key do |field|
      counts[field] = scope.where(
        "#{field} IS NOT NULL AND COALESCE(#{field}::text, '[]') != '[]'"
      ).count
    end

    counts
  end

  def clear_attributes
    attrs = STRING_FIELDS.index_with { nil }
    attrs.merge!(JSON_FIELDS)
    attrs.merge(updated_at: Time.current)
  end

  def remaining_record_summary(text_content)
    {
      id: text_content.id,
      unit_key: text_content.unit_key,
      addressed_party_code: text_content.addressed_party_code,
      addressed_party_custom_name: text_content.addressed_party_custom_name,
      responsible_party_code: text_content.responsible_party_code,
      responsible_party_custom_name: text_content.responsible_party_custom_name,
      genre_code: text_content.genre_code,
      lsv_literal_reconstruction: text_content.lsv_literal_reconstruction,
      word_for_word_translation: text_content.word_for_word_translation
    }
  end
end
