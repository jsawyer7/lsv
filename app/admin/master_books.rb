ActiveAdmin.register MasterBook do
  permit_params :code, :title, :family_code, :origin_lang, :notes

  # Custom page title
  menu label: "Master Books", priority: 7

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Master Books Management", class: "mb-2"
      para "Manage master books and their configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Title", class: "form-label"
            input type: "text", name: "q[title_cont]", placeholder: "Search title...", class: "form-control", value: params.dig(:q, :title_cont)
          end
          div class: "col-md-3" do
            label "Code", class: "form-label"
            input type: "text", name: "q[code_cont]", placeholder: "Search code...", class: "form-control", value: params.dig(:q, :code_cont)
          end
          div class: "col-md-3" do
            label "Family Code", class: "form-label"
            input type: "text", name: "q[family_code_cont]", placeholder: "Search family...", class: "form-control", value: params.dig(:q, :family_code_cont)
          end
          div class: "col-md-3" do
            label "Origin Language", class: "form-label"
            input type: "text", name: "q[origin_lang_cont]", placeholder: "Search language...", class: "form-control", value: params.dig(:q, :origin_lang_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterBooks()" do
            "Filter"
          end
          a href: admin_master_books_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterBooks() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_master_books_path}';

          var title = document.querySelector('input[name=\"q[title_cont]\"]').value;
          var code = document.querySelector('input[name=\"q[code_cont]\"]').value;
          var familyCode = document.querySelector('input[name=\"q[family_code_cont]\"]').value;
          var originLang = document.querySelector('input[name=\"q[origin_lang_cont]\"]').value;

          if (title) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[title_cont]';
            input.value = title;
            form.appendChild(input);
          }

          if (code) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[code_cont]';
            input.value = code;
            form.appendChild(input);
          }

          if (familyCode) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[family_code_cont]';
            input.value = familyCode;
            form.appendChild(input);
          }

          if (originLang) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[origin_lang_cont]';
            input.value = originLang;
            form.appendChild(input);
          }

          document.body.appendChild(form);
          form.submit();
        }
      ")
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "CODE", class: "fw-semibold"
            th "TITLE", class: "fw-semibold"
            th "FAMILY", class: "fw-semibold"
            th "ORIGIN LANGUAGE", class: "fw-semibold"
            th "NOTES", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          master_books.each do |book|
            tr do
              # CODE column
              td do
                span class: "text-body fw-semibold" do
                  book.code
                end
              end

              # TITLE column
              td do
                div class: "fw-semibold" do
                  book.title
                end
              end

              # FAMILY column
              td do
                span class: "text-body" do
                  book.family_code
                end
              end

              # ORIGIN LANGUAGE column
              td do
                span class: "text-body" do
                  book.origin_lang
                end
              end

              # NOTES column
              td do
                span class: "text-body" do
                  book.notes.present? ? truncate(book.notes, length: 30) : "N/A"
    end
  end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_master_book_path(book)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_master_book_path(book)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_master_book_path(book)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :title
  filter :code
  filter :family_code
  filter :origin_lang
  filter :created_at

  form do |f|

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Edit Master Book", class: "mb-2 text-primary"
          para "Update master book information and settings", class: "text-muted mb-0"
        end
        div do
          link_to "Back to Master Books", admin_master_books_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-edit-line me-2"
          "Book Information"
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Book Code"
            end
            f.input :code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter book code..."
                    }
          end

          # Title Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-2-line me-2"
              span "Book Title"
            end
            f.input :title,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter book title..."
                    }
          end

          # Family Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-group-line me-2"
              span "Family Code"
            end
            f.input :family_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter family code..."
                    }
          end

          # Origin Language Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Origin Language"
            end
            f.input :origin_lang,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter origin language..."
                    }
          end

          # Notes Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-text-line me-2"
              span "Notes"
            end
            f.input :notes,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter notes...",
                      rows: 4
                    }
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: "Update Book",
                     class: "materio-btn-primary"
            f.action :cancel,
                     label: "Cancel",
                     class: "materio-btn-secondary"
          end
        end
      end
    end
  end

  show do

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Master Book Details", class: "mb-2 text-primary"
          para "View detailed information about this master book", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Book", edit_admin_master_book_path(master_book), class: "btn btn-primary"
          link_to "Back to Master Books", admin_master_books_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Book Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-book-2-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do master_book.title end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do master_book.code end
              span class: "badge bg-info fs-6" do master_book.family_code end
            end
            if master_book.notes.present?
              p class: "text-muted mb-0" do master_book.notes end
            end
          end
        end
      end

      # Book Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Book Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-code-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Book Code" end
                    div class: "fw-semibold" do master_book.code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-book-2-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Book Title" end
                    div class: "fw-semibold" do master_book.title end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-group-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Family Code" end
                    div class: "fw-semibold" do master_book.family_code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-global-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Origin Language" end
                    div class: "fw-semibold" do master_book.origin_lang end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do master_book.id end
                  div class: "materio-metric-label" do "Book ID" end
                end
              end
              if master_book.notes.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Notes"
                    end
                    div class: "fw-semibold" do master_book.notes end
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
