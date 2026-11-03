module LsvMcp
  module Tools
    class ListBooks < LsvMcp::Tool
      requires_scope 'scripture'
      tool_name 'list_books'
      description 'List book codes (GEN, EXO, MAT, 1CO, …) and names. With a canon code, list that canon\'s books ' \
                  'in canonical order. Without one, also returns the available canons.'
      input_schema(
        properties: {
          canon: { type: 'string', maxLength: 50, description: 'Canon code; omit to list all books and all canons.' }
        },
        additionalProperties: false
      )

      def run(canon: nil)
        if canon.present?
          record = Canon.unscoped.find_by(code: canon.strip) || Canon.unscoped.where('lower(code) = lower(?)', canon.strip).first
          raise Error, "Unknown canon #{canon.inspect}. Call list_books without a canon to see canon codes." unless record

          books = CanonBook.unscoped.where(canon_id: record.id).includes(:book).order(:seq_no).map do |cb|
            { code: cb.book.code, name: cb.book.std_name, order: cb.seq_no, included: cb.included_bool }
          end
          { canon: { code: record.code, name: record.name, description: record.description }, count: books.size, books: books }
        else
          books = Book.unscoped.order(:code).map { |b| { code: b.code, name: b.std_name } }
          canons = Canon.unscoped.order(:code).map { |c| { code: c.code, name: c.name } }
          { count: books.size, books: books, canons: canons }
        end
      end
    end
  end
end
