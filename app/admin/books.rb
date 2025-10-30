ActiveAdmin.register Book do
  permit_params :code, :std_name, :description

  # Custom page title
  menu parent: "Data Tables", label: "Books", priority: 4

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  # Add action items for CRUD operations
  action_item :new_book, only: :index do
    link_to "Add Book", new_admin_book_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Book Management", class: "mb-2"
          para "Manage books (Genesis, Exodus, John, Psalms, 1 Enoch, etc.)", class: "text-muted"
        end
        div do
          link_to "Add Book", new_admin_book_path, class: "btn btn-primary"
        end
      end
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "Code", class: "fw-semibold"
            th "Standard Name", class: "fw-semibold"
            th "Description", class: "fw-semibold"
            th "Canons Count", class: "fw-semibold"
            th "Actions", class: "fw-semibold"
          end
        end
        tbody do
          books.each do |book|
            tr do
              td do
                span class: "badge bg-primary" do book.code end
              end
              td do
                span class: "fw-semibold" do book.std_name end
              end
              td do
                span class: "text-muted" do book.description || "No description" end
              end
              td do
                span class: "badge bg-info" do book.canons.count end
              end
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_book_path(book)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_book_path(book)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_book_path(book)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :code
  filter :std_name
  filter :description

  form do |f|
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          if f.object.new_record?
            h1 "Create Book", class: "mb-2 text-primary"
            para "Add new book to the system", class: "text-muted mb-0"
          else
            h1 "Edit Book", class: "mb-2 text-primary"
            para "Update book information", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Books", admin_books_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-book-open-line me-2"
          "Book Information"
        end
      end
      div class: "card-body p-5" do
        style do
          raw "ol { list-style: none; counter-reset: none; } ol li { counter-increment: none; } ol li::before { content: none; }"
        end
        f.inputs do
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Book Code"
            end
            f.input :code,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter book code (e.g., GEN, EXO, JOHN, PS, ENO1)..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-open-line me-2"
              span "Standard Name"
            end
            f.input :std_name,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter standard name (e.g., Genesis, Exodus, John, Psalms, 1 Enoch)..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-text-line me-2"
              span "Description"
            end
            f.input :description,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter description (e.g., 'First book of the Torah')...",
                      rows: 3
                    }
          end
        end

        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Book", type: "submit", class: "btn btn-primary"
            else
              button "Update Book", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_books_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Book: #{book.std_name}", class: "mb-1 fw-bold text-dark"
        p "Code: #{book.code}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Book", edit_admin_book_path(book), class: "btn btn-primary px-3 py-2"
        link_to "Back to Books", admin_books_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-book-open-line me-2"
              "Book Details"
            end
          end
          div class: "card-body p-4" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-code-line me-2"
                    "Book Code"
                  end
                  div class: "fw-semibold text-dark" do book.code end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-book-open-line me-2"
                    "Standard Name"
                  end
                  div class: "fw-semibold text-dark" do book.std_name end
                end
              end
              div class: "col-12" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-file-text-line me-2"
                    "Description"
                  end
                  div class: "fw-semibold text-dark" do book.description || "No description provided" end
                end
              end
            end
          end
        end
      end

      div class: "col-lg-4" do
        div class: "materio-metric-card materio-metric-card-light" do
          div class: "materio-icon primary" do
            i class: "ri ri-list-check"
          end
          h6 "Canons Count", class: "mb-2 fw-semibold"
          div class: "fw-bold text-dark mb-2" do book.canons.count end
          p "Canons containing this book", class: "text-muted small mb-0"
        end
      end
    end

    if book.canons.any?
      div class: "row mt-4" do
        div class: "col-12" do
          div class: "materio-card" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-list-check me-2"
                "Canons containing this Book"
              end
            end
            div class: "card-body p-4" do
              div class: "table-responsive" do
                table class: "table table-sm" do
                  thead do
                    tr do
                      th "Canon"
                      th "Sequence"
                      th "Included"
                    end
                  end
                  tbody do
                    book.canon_books.includes(:canon).ordered.each do |canon_book|
                      tr do
                        td do
                          link_to canon_book.canon.name, admin_canon_path(canon_book.canon), class: "text-decoration-none"
                        end
                        td do
                          span class: "badge bg-secondary" do canon_book.seq_no end
                        end
                        td do
                          span class: "badge bg-#{canon_book.included_bool? ? 'success' : 'danger'}" do
                            canon_book.included_bool? ? 'Yes' : 'No'
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
