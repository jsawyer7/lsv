ActiveAdmin.register CanonBook do
  permit_params :canon_id, :book_id, :seq_no, :included_bool, :description

  # Custom page title
  menu label: "Canon Books", priority: 9

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  # Add action items for CRUD operations
  action_item :new_canon_book, only: :index do
    link_to "Add Canon Book", new_admin_canon_book_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Canon-Book Management", class: "mb-2"
          para "Manage canon-book relationships and ordering", class: "text-muted"
        end
        div do
          link_to "Add Canon Book", new_admin_canon_book_path, class: "btn btn-primary"
        end
      end
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "Canon", class: "fw-semibold"
            th "Book", class: "fw-semibold"
            th "Sequence", class: "fw-semibold"
            th "Included", class: "fw-semibold"
            th "Description", class: "fw-semibold"
            th "Actions", class: "fw-semibold"
          end
        end
        tbody do
          canon_books.each do |canon_book|
            tr do
              td do
                span class: "badge bg-primary" do canon_book.canon.name end
              end
              td do
                span class: "fw-semibold" do canon_book.book.std_name end
              end
              td do
                span class: "badge bg-secondary" do canon_book.seq_no end
              end
              td do
                span class: "badge bg-#{canon_book.included_bool? ? 'success' : 'danger'}" do
                  canon_book.included_bool? ? 'Yes' : 'No'
                end
              end
              td do
                span class: "text-muted" do canon_book.description || "No description" end
              end
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_canon_book_path(canon_book)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_canon_book_path(canon_book)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_canon_book_path(canon_book)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :canon
  filter :book
  filter :seq_no
  filter :included_bool

  form do |f|
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          if f.object.new_record?
            h1 "Create Canon-Book Relationship", class: "mb-2 text-primary"
            para "Add new canon-book relationship", class: "text-muted mb-0"
          else
            h1 "Edit Canon-Book Relationship", class: "mb-2 text-primary"
            para "Update canon-book relationship", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Canon Books", admin_canon_books_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-list-check me-2"
          "Canon-Book Relationship"
        end
      end
      div class: "card-body p-5" do
        style do
          raw "ol { list-style: none; counter-reset: none; } ol li { counter-increment: none; } ol li::before { content: none; }"
        end
        f.inputs do
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-check me-2"
              span "Canon"
            end
            f.input :canon_id,
                    as: :select,
                    collection: Canon.ordered.map { |canon| [canon.display_name, canon.id] },
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Select canon..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-open-line me-2"
              span "Book"
            end
            f.input :book_id,
                    as: :select,
                    collection: Book.ordered.map { |book| [book.display_name, book.id] },
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Select book..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-sort-asc me-2"
              span "Sequence Number"
            end
            f.input :seq_no,
                    as: :number,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter sequence number...",
                      min: 1
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-checkbox-line me-2"
              span "Included"
            end
            f.input :included_bool,
                    as: :boolean,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "form-check-input"
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-text-line me-2"
              span "Description (Optional)"
            end
            f.input :description,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter description (e.g., 'Catholic Psalms ends at 150')...",
                      rows: 3
                    }
          end
        end

        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Relationship", type: "submit", class: "btn btn-primary"
            else
              button "Update Relationship", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_canon_books_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Canon-Book Relationship", class: "mb-1 fw-bold text-dark"
        p "#{canon_book.canon.name} - #{canon_book.book.std_name}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Relationship", edit_admin_canon_book_path(canon_book), class: "btn btn-primary px-3 py-2"
        link_to "Back to Canon Books", admin_canon_books_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-list-check me-2"
              "Relationship Details"
            end
          end
          div class: "card-body p-4" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-list-check me-2"
                    "Canon"
                  end
                  div class: "fw-semibold text-dark" do
                    link_to canon_book.canon.name, admin_canon_path(canon_book.canon), class: "text-decoration-none"
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-book-open-line me-2"
                    "Book"
                  end
                  div class: "fw-semibold text-dark" do
                    link_to canon_book.book.std_name, admin_book_path(canon_book.book), class: "text-decoration-none"
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-sort-asc me-2"
                    "Sequence Number"
                  end
                  div class: "fw-semibold text-dark" do canon_book.seq_no end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-checkbox-line me-2"
                    "Included"
                  end
                  div class: "fw-semibold" do
                    span class: "badge bg-#{canon_book.included_bool? ? 'success' : 'danger'}" do
                      canon_book.included_bool? ? 'Yes' : 'No'
                    end
                  end
                end
              end
              if canon_book.description.present?
                div class: "col-12" do
                  div class: "materio-info-item" do
                    div class: "text-muted small fw-semibold mb-2" do
                      i class: "ri ri-file-text-line me-2"
                      "Description"
                    end
                    div class: "fw-semibold text-dark" do canon_book.description end
                  end
                end
              end
            end
          end
        end
      end

      div class: "col-lg-4" do
        div class: "materio-metric-card materio-metric-card-light" do
          div class: "materio-icon primary" do
            i class: "ri ri-sort-asc"
          end
          h6 "Sequence", class: "mb-2 fw-semibold"
          div class: "fw-bold text-dark mb-2" do canon_book.seq_no end
          p "Order in canon", class: "text-muted small mb-0"
        end
      end
    end
  end
end
