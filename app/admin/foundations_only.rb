ActiveAdmin.register FoundationsOnly do
  permit_params :code, :title, :tradition_code, :lang_code, :scope, :pub_range, :citation_hint, :is_active

  # Custom page title
  menu label: "Religious Texts", priority: 5

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Religious Texts Management", class: "mb-2"
      para "Manage religious texts and their configurations", class: "text-muted"
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
            label "Tradition", class: "form-label"
            input type: "text", name: "q[tradition_code_cont]", placeholder: "Search tradition...", class: "form-control", value: params.dig(:q, :tradition_code_cont)
          end
          div class: "col-md-3" do
            label "Status", class: "form-label"
            select name: "q[is_active_eq]", class: "form-select" do
              option "All Status", value: ""
              option "Active", value: "true", selected: params.dig(:q, :is_active_eq) == "true"
              option "Inactive", value: "false", selected: params.dig(:q, :is_active_eq) == "false"
            end
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterFoundations()" do
            "Filter"
          end
          a href: admin_foundations_onlies_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterFoundations() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_foundations_onlies_path}';

          var title = document.querySelector('input[name=\"q[title_cont]\"]').value;
          var code = document.querySelector('input[name=\"q[code_cont]\"]').value;
          var tradition = document.querySelector('input[name=\"q[tradition_code_cont]\"]').value;
          var status = document.querySelector('select[name=\"q[is_active_eq]\"]').value;

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

          if (tradition) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[tradition_code_cont]';
            input.value = tradition;
            form.appendChild(input);
          }

          if (status && status !== 'All Status') {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[is_active_eq]';
            input.value = status;
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
            th "TRADITION", class: "fw-semibold"
            th "LANGUAGE", class: "fw-semibold"
            th "SCOPE", class: "fw-semibold"
            th "STATUS", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          foundations_onlies.each do |foundation|
            tr do
              # CODE column
              td do
                span class: "text-body fw-semibold" do
                  foundation.code
                end
              end

              # TITLE column
              td do
                div class: "fw-semibold" do
                  foundation.title
                end
              end

              # TRADITION column
              td do
                span class: "text-body" do
                  foundation.tradition_code
                end
              end

              # LANGUAGE column
              td do
                span class: "text-body" do
                  foundation.lang_code
                end
              end

              # SCOPE column
              td do
                span class: "text-body" do
                  foundation.scope
                end
              end

              # STATUS column with badge
              td do
                if foundation.is_active?
                  span class: "badge bg-success" do
                    "Active"
                  end
                else
                  span class: "badge bg-danger" do
                    "Inactive"
                  end
    end
  end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_foundations_only_path(foundation)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_foundations_only_path(foundation)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_foundations_only_path(foundation)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
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
  filter :tradition_code
  filter :lang_code
  filter :scope
  filter :is_active
  filter :created_at

  form do |f|
    # Custom CSS for simple form design
    style do
      raw <<-CSS
        .materio-form-card {
          border: 1px solid #e7eaf3;
          border-radius: 0.75rem;
          box-shadow: 0 0.125rem 0.25rem rgba(165, 163, 174, 0.3);
          transition: all 0.3s ease;
        }
        .materio-form-card:hover {
          box-shadow: 0 0.5rem 1rem rgba(165, 163, 174, 0.15);
        }
        .materio-form-header {
          background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
          color: white;
          border-radius: 0.75rem 0.75rem 0 0;
          padding: 1.5rem;
        }
        .materio-form-group {
          margin-bottom: 1.5rem;
        }
        .materio-form-label {
          font-weight: 600;
          color: #697a8d;
          margin-bottom: 0.5rem;
          font-size: 0.875rem;
          display: flex;
          align-items: center;
        }
        .materio-form-control {
          border: 1px solid #e7eaf3;
          border-radius: 0.5rem;
          padding: 0.75rem 1rem;
          font-size: 0.875rem;
          transition: all 0.3s ease;
        }
        .materio-form-control:focus {
          border-color: #696cff;
          box-shadow: 0 0 0 0.2rem rgba(105, 108, 255, 0.25);
        }
        .materio-btn-primary {
          background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
          border: none;
          border-radius: 0.5rem;
          color: white;
          font-weight: 600;
          font-size: 0.875rem;
          padding: 0.75rem 2rem;
          transition: all 0.3s ease;
          box-shadow: 0 0.125rem 0.25rem rgba(105, 108, 255, 0.3);
        }
        .materio-btn-primary:hover {
          background: linear-gradient(135deg, #5a5fcf 0%, #4a4fb8 100%);
          transform: translateY(-1px);
          box-shadow: 0 0.25rem 0.5rem rgba(105, 108, 255, 0.4);
          color: white;
        }
        .materio-btn-secondary {
          background: white;
          border: 1px solid #e7eaf3;
          border-radius: 0.5rem;
          color: #697a8d;
          font-weight: 600;
          font-size: 0.875rem;
          padding: 0.75rem 2rem;
          transition: all 0.3s ease;
        }
        .materio-btn-secondary:hover {
          background: #f8f9fa;
          border-color: #d9dee3;
          color: #2b2c40;
          transform: translateY(-1px);
          box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.1);
        }
      CSS
    end

    # Page Header
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Edit Religious Text", class: "mb-1 fw-bold text-dark"
        p "Update religious text information and settings", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Back to Religious Texts", admin_foundations_onlies_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    # Main Form Content
    div class: "materio-form-card" do
      div class: "materio-form-header" do
        h5 class: "mb-0 fw-semibold" do
          i class: "ri ri-edit-line me-2"
          "Text Information"
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Text Code"
            end
            f.input :code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter text code..."
                    }
          end

          # Title Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-open-line me-2"
              span "Text Title"
            end
            f.input :title,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter text title..."
                    }
          end

          # Tradition Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Tradition Code"
            end
            f.input :tradition_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter tradition code..."
                    }
          end

          # Language Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-translate me-2"
              span "Language Code"
            end
            f.input :lang_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter language code..."
                    }
          end

          # Scope Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-focus-line me-2"
              span "Scope"
            end
            f.input :scope,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter scope..."
                    }
          end

          # Publication Range Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-calendar-line me-2"
              span "Publication Range"
            end
            f.input :pub_range,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter publication range..."
                    }
          end

          # Citation Hint Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-text-line me-2"
              span "Citation Hint"
            end
            f.input :citation_hint,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter citation hint...",
                      rows: 3
                    }
          end

          # Active Status
          div class: "materio-form-group" do
            div class: "d-flex align-items-center mb-2" do
              i class: "ri ri-toggle-line me-2"
              span "Status"
            end
            div class: "form-check form-switch" do
              f.check_box :is_active,
                         class: "form-check-input",
                         role: "switch"
            end
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: "Update Text",
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
    # Custom CSS for Materio-style design
    style do
      raw <<-CSS
        .materio-card {
          border: 1px solid #e7eaf3;
          border-radius: 0.75rem;
          box-shadow: 0 0.125rem 0.25rem rgba(165, 163, 174, 0.3);
          transition: all 0.3s ease;
        }
        .materio-card:hover {
          box-shadow: 0 0.5rem 1rem rgba(165, 163, 174, 0.15);
          transform: translateY(-2px);
        }
        .materio-header {
          background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
          color: white;
          border-radius: 0.75rem 0.75rem 0 0;
          padding: 1.5rem;
        }
        .materio-info-card {
          background: linear-gradient(135deg, #71dd37 0%, #5cb85c 100%);
          color: white;
          border-radius: 0.75rem 0.75rem 0 0;
          padding: 1.5rem;
        }
        .materio-badge {
          background: rgba(105, 108, 255, 0.1);
          color: #696cff;
          border: 1px solid rgba(105, 108, 255, 0.2);
          padding: 0.5rem 1rem;
          border-radius: 0.5rem;
          font-weight: 600;
          font-size: 0.875rem;
        }
        .materio-info-item {
          background: #f8f9fa;
          border: 1px solid #e7eaf3;
          border-radius: 0.5rem;
          padding: 1rem;
          margin-bottom: 0.75rem;
        }
        .materio-metric-card {
          background: white;
          border: 1px solid #e7eaf3;
          border-radius: 0.75rem;
          padding: 1.5rem;
          text-align: center;
          transition: all 0.3s ease;
        }
        .materio-metric-card:hover {
          transform: translateY(-2px);
          box-shadow: 0 0.5rem 1rem rgba(165, 163, 174, 0.15);
        }
        .materio-icon {
          width: 3rem;
          height: 3rem;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0 auto 1rem;
          font-size: 1.5rem;
        }
        .materio-icon.primary { background: rgba(105, 108, 255, 0.1); color: #696cff; }
        .materio-icon.success { background: rgba(113, 221, 55, 0.1); color: #71dd37; }
        .materio-icon.warning { background: rgba(255, 171, 0, 0.1); color: #ffab00; }
        .materio-icon.info { background: rgba(133, 146, 163, 0.1); color: #8592a3; }
        .materio-avatar {
          width: 5rem;
          height: 5rem;
          border-radius: 50%;
          border: 3px solid #696cff;
          margin: 0 auto 1.5rem;
          display: flex;
          align-items: center;
          justify-content: center;
        }
      CSS
    end

    # Page Header
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Religious Text Details", class: "mb-2 text-primary"
        para "View detailed information about this religious text", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Text", edit_admin_foundations_only_path(foundations_only), class: "btn btn-primary"
        link_to "Back to Religious Texts", admin_foundations_onlies_path, class: "btn btn-outline-secondary"
      end
    end

    div class: "row g-4" do
      # Left Column - Text Profile
      div class: "col-lg-4" do
        div class: "materio-card" do
          div class: "materio-header" do
            div class: "text-center" do
              div class: "materio-avatar" do
                i class: "ri ri-book-open-line text-white", style: "font-size: 2rem;"
              end
              h4 class: "mb-1 text-white" do
                foundations_only.title
              end
              p class: "text-white-50 mb-0" do
                foundations_only.code
              end
            end
          end
          div class: "card-body p-4" do
            div class: "text-center mb-3" do
              span class: "badge bg-#{foundations_only.is_active? ? 'success' : 'danger'} fs-6 px-3 py-2" do
                foundations_only.is_active? ? "Active" : "Inactive"
              end
            end

            # Action Buttons
            div class: "d-flex gap-2 mt-3" do
              link_to "Edit", edit_admin_foundations_only_path(foundations_only), class: "btn btn-primary flex-fill"
              link_to "Delete", admin_foundations_only_path(foundations_only), method: :delete,
                      data: { confirm: "Are you sure you want to delete this text? This action cannot be undone." },
                      class: "btn btn-outline-danger flex-fill"
            end
          end
        end
      end

      # Right Column - Text Information
      div class: "col-lg-8" do
        # Text Information Card
        div class: "materio-card mb-4" do
          div class: "materio-info-card" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-information-line me-2"
              "Text Information"
            end
          end
          div class: "card-body p-4" do
            # Metric-style cards for key information
            div class: "row g-3 mb-4" do
              div class: "col-md-4" do
                div class: "materio-metric-card" do
                  div class: "materio-icon primary" do
                    i class: "ri ri-code-line"
                  end
                  h6 class: "mb-1" do "Code" end
                  h4 class: "mb-0 text-primary" do
                    foundations_only.code
                  end
                end
              end
              div class: "col-md-4" do
                div class: "materio-metric-card" do
                  div class: "materio-icon success" do
                    i class: "ri ri-translate"
                  end
                  h6 class: "mb-1" do "Language" end
                  h4 class: "mb-0 text-success" do
                    foundations_only.lang_code
                  end
                end
              end
              div class: "col-md-4" do
                div class: "materio-metric-card" do
                  div class: "materio-icon #{foundations_only.is_active? ? 'success' : 'warning'}" do
                    i class: "ri ri-#{foundations_only.is_active? ? 'check-line' : 'close-line'}"
                  end
                  h6 class: "mb-1" do "Status" end
                  h4 class: "mb-0 #{foundations_only.is_active? ? 'text-success' : 'text-warning'}" do
                    foundations_only.is_active? ? "Active" : "Inactive"
                  end
                end
              end
            end

            # Additional information in traditional format
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "fw-semibold text-muted mb-1" do
                    i class: "ri ri-global-line me-2"
                    "Tradition Code"
                  end
                  div class: "fw-bold text-dark" do
                    foundations_only.tradition_code
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "fw-semibold text-muted mb-1" do
                    i class: "ri ri-focus-line me-2"
                    "Scope"
                  end
                  div class: "fw-bold text-dark" do
                    foundations_only.scope
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "fw-semibold text-muted mb-1" do
                    i class: "ri ri-calendar-line me-2"
                    "Publication Range"
                  end
                  div class: "fw-bold text-dark" do
                    foundations_only.pub_range
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "fw-semibold text-muted mb-1" do
                    i class: "ri ri-book-open-line me-2"
                    "Text Title"
                  end
                  div class: "fw-bold text-dark" do
                    foundations_only.title
                  end
                end
              end
            end

            # Citation Hint
            if foundations_only.citation_hint.present?
              div class: "mt-3" do
                div class: "materio-info-item" do
                  div class: "fw-semibold text-muted mb-2" do
                    i class: "ri ri-file-text-line me-2"
                    "Citation Hint"
                  end
                  div class: "text-dark" do
                    foundations_only.citation_hint
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
