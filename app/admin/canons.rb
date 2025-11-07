ActiveAdmin.register Canon do
  permit_params :code, :name, :description

  # Custom page title
  menu parent: "Data Tables", label: "Canons", priority: 5

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end
  
  config.sort_order = 'created_at_asc'

  # Add action items for CRUD operations
  action_item :new_canon, only: :index do
    link_to "Add Canon", new_admin_canon_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Canon Management", class: "mb-2"
          para "Manage canons (Catholic, Protestant, Ethiopian, Orthodox, etc.)", class: "text-muted"
        end
        div do
          link_to "Add Canon", new_admin_canon_path, class: "btn btn-primary"
        end
      end
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "Code", class: "fw-semibold"
            th "Name", class: "fw-semibold"
            th "Description", class: "fw-semibold"
            th "Books Count", class: "fw-semibold"
            th "Actions", class: "fw-semibold"
          end
        end
        tbody do
          canons.each do |canon|
            tr do
              td do
                span class: "badge bg-primary" do canon.code end
              end
              td do
                span class: "fw-semibold" do canon.name end
              end
              td do
                span class: "text-muted" do canon.description || "No description" end
              end
              td do
                span class: "badge bg-info" do canon.books.count end
              end
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_canon_path(canon)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_canon_path(canon)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_canon_path(canon)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :code
  filter :name
  filter :description

  form do |f|
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          if f.object.new_record?
            h1 "Create Canon", class: "mb-2 text-primary"
            para "Add new canon to the system", class: "text-muted mb-0"
          else
            h1 "Edit Canon", class: "mb-2 text-primary"
            para "Update canon information", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Canons", admin_canons_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-list-check me-2"
          "Canon Information"
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
              span "Canon Code"
            end
            f.input :code,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter canon code (e.g., CATH, PROT, ETH, ORTH)..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-check me-2"
              span "Canon Name"
            end
            f.input :name,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter canon name (e.g., Catholic, Protestant, Ethiopian, Orthodox)..."
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
                      placeholder: "Enter description (e.g., 'Roman Catholic canon, 73 books')...",
                      rows: 3
                    }
          end
        end

        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Canon", type: "submit", class: "btn btn-primary"
            else
              button "Update Canon", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_canons_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Canon: #{canon.name}", class: "mb-1 fw-bold text-dark"
        p "Code: #{canon.code}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Canon", edit_admin_canon_path(canon), class: "btn btn-primary px-3 py-2"
        link_to "Back to Canons", admin_canons_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-list-check me-2"
              "Canon Details"
            end
          end
          div class: "card-body p-4" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-code-line me-2"
                    "Canon Code"
                  end
                  div class: "fw-semibold text-dark" do canon.code end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-list-check me-2"
                    "Canon Name"
                  end
                  div class: "fw-semibold text-dark" do canon.name end
                end
              end
              div class: "col-12" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-file-text-line me-2"
                    "Description"
                  end
                  div class: "fw-semibold text-dark" do canon.description || "No description provided" end
                end
              end
            end
          end
        end
      end

      div class: "col-lg-4" do
        div class: "materio-metric-card materio-metric-card-light" do
          div class: "materio-icon primary" do
            i class: "ri ri-book-line"
          end
          h6 "Books Count", class: "mb-2 fw-semibold"
          div class: "fw-bold text-dark mb-2" do canon.books.count end
          p "Books in this canon", class: "text-muted small mb-0"
        end
      end
    end

    if canon.books.any?
      div class: "row mt-4" do
        div class: "col-12" do
          div class: "materio-card" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-book-line me-2"
                "Books in this Canon"
              end
            end
            div class: "card-body p-4" do
              div class: "table-responsive" do
                table class: "table table-sm" do
                  thead do
                    tr do
                      th "Sequence"
                      th "Book"
                      th "Code"
                      th "Included"
                    end
                  end
                  tbody do
                    canon.canon_books.includes(:book).ordered.each do |canon_book|
                      tr do
                        td do
                          span class: "badge bg-secondary" do canon_book.seq_no end
                        end
                        td do
                          link_to canon_book.book.std_name, admin_book_path(canon_book.book), class: "text-decoration-none"
                        end
                        td do
                          span class: "badge bg-primary" do canon_book.book.code end
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
