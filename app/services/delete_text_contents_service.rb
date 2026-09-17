# Deletes text_contents records (all sources/books by default).
# Dependent canon_text_contents / text_translations are removed first when present.
# text_content_api_logs are left in place (optional association, no FK).
class DeleteTextContentsService
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
    before_by_source = counts_by_source(scope)
    total = scope.count
    ids = scope.pluck(:id)

    dependent_counts = {
      canon_text_contents: CanonTextContent.where(text_content_id: ids).count,
      text_translations: TextTranslation.where(text_content_id: ids).count,
      child_parent_links: scope.where.not(parent_unit_id: nil).count
    }

    deleted = 0
    unless @dry_run
      deleted = delete_records!(scope, ids)
    end

    remaining = resolve_scope.count

    {
      dry_run: @dry_run,
      total_records: total,
      deleted_count: deleted,
      would_delete: @dry_run ? total : 0,
      remaining_count: remaining,
      before_by_source: before_by_source,
      dependent_counts: dependent_counts,
      verified: remaining.zero? && (@all || (@source_id.present? || @book_code.present?)),
      source: @source,
      book: @book
    }
  end

  private

  def resolve_scope
    base = TextContent.unscoped

    if @all
      return base
    end

    if @source_id.blank? && @book_code.blank?
      raise ScopeError, "Provide source_id and/or book_code, or set all: true"
    end

    if @source_id.present?
      @source = Source.unscoped.find_by(id: @source_id.to_i) ||
                Source.unscoped.find_by(code: @source_id.to_s)
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

  def counts_by_source(scope)
    scope.joins(:source).group('sources.code').count
  end

  def delete_records!(scope, ids)
    return 0 if ids.empty?

    # Break self-referential parent links before bulk delete
    scope.where.not(parent_unit_id: nil).update_all(parent_unit_id: nil, updated_at: Time.current)

    CanonTextContent.where(text_content_id: ids).delete_all
    TextTranslation.where(text_content_id: ids).delete_all

    # Batched delete for large tables
    deleted = 0
    ids.each_slice(1000) do |batch_ids|
      deleted += TextContent.unscoped.where(id: batch_ids).delete_all
    end
    deleted
  end
end
