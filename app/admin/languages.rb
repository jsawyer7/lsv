ActiveAdmin.register Language do
  permit_params :code, :name, :iso_639_3, :script, :direction, :language_family, :notes

  # Custom page title
  menu label: "Languages", priority: 6

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Languages Management", class: "mb-2"
      para "Manage languages and their configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Name", class: "form-label"
            input type: "text", name: "q[name_cont]", placeholder: "Search name...", class: "form-control", value: params.dig(:q, :name_cont)
          end
          div class: "col-md-3" do
            label "Code", class: "form-label"
            input type: "text", name: "q[code_cont]", placeholder: "Search code...", class: "form-control", value: params.dig(:q, :code_cont)
          end
          div class: "col-md-3" do
            label "Script", class: "form-label"
            input type: "text", name: "q[script_cont]", placeholder: "Search script...", class: "form-control", value: params.dig(:q, :script_cont)
          end
          div class: "col-md-3" do
            label "Family", class: "form-label"
            input type: "text", name: "q[language_family_cont]", placeholder: "Search family...", class: "form-control", value: params.dig(:q, :language_family_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterLanguages()" do
            "Filter"
          end
          a href: admin_languages_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterLanguages() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_languages_path}';

          var name = document.querySelector('input[name=\"q[name_cont]\"]').value;
          var code = document.querySelector('input[name=\"q[code_cont]\"]').value;
          var script = document.querySelector('input[name=\"q[script_cont]\"]').value;
          var family = document.querySelector('input[name=\"q[language_family_cont]\"]').value;

          if (name) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[name_cont]';
            input.value = name;
            form.appendChild(input);
          }

          if (code) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[code_cont]';
            input.value = code;
            form.appendChild(input);
          }

          if (script) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[script_cont]';
            input.value = script;
            form.appendChild(input);
          }

          if (family) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[language_family_cont]';
            input.value = family;
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
            th "NAME", class: "fw-semibold"
            th "ISO CODE", class: "fw-semibold"
            th "SCRIPT", class: "fw-semibold"
            th "DIRECTION", class: "fw-semibold"
            th "FAMILY", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          languages.each do |language|
            tr do
              # CODE column
              td do
                span class: "text-body fw-semibold" do
                  language.code
                end
              end

              # NAME column
              td do
                div class: "fw-semibold" do
                  language.name
                end
              end

              # ISO CODE column
              td do
                span class: "text-body" do
                  language.iso_639_3
                end
              end

              # SCRIPT column
              td do
                span class: "text-body" do
                  language.script
                end
              end

              # DIRECTION column
              td do
                span class: "text-body" do
                  language.direction
                end
              end

              # FAMILY column
              td do
                span class: "text-body" do
                  language.language_family
    end
  end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_language_path(language)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_language_path(language)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_language_path(language)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :name
  filter :code
  filter :script
  filter :direction
  filter :language_family
  filter :created_at

  form do |f|
    # Custom CSS for Materio UI
    style do
      raw("
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
          background-color: #fff;
        }
        .materio-form-control:focus {
          border-color: #696cff;
          box-shadow: 0 0 0 0.2rem rgba(105, 108, 255, 0.25);
          outline: none;
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
      ")
    end

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Edit Language", class: "mb-2 text-primary"
          para "Update language information and settings", class: "text-muted mb-0"
        end
        div do
          link_to "Back to Languages", admin_languages_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-edit-line me-2"
          "Language Information"
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Language Code"
            end
            f.input :code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter language code..."
                    }
          end

          # Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Language Name"
            end
            f.input :name,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter language name..."
                    }
          end

          # ISO 639-3 Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "ISO 639-3 Code"
            end
            f.input :iso_639_3,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter ISO 639-3 code..."
                    }
          end

          # Script Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-text me-2"
              span "Script"
            end
            f.input :script,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter script..."
                    }
          end

          # Direction Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-arrow-left-right-line me-2"
              span "Text Direction"
            end
            f.input :direction,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter text direction..."
                    }
          end

          # Language Family Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-group-line me-2"
              span "Language Family"
            end
            f.input :language_family,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter language family..."
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
                     label: "Update Language",
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
    # Custom CSS for Materio UI
    style do
      raw("
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
        .materio-metric-card {
          background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
          border-radius: 1rem;
          padding: 1.5rem;
          color: white;
          text-align: center;
          box-shadow: 0 0.5rem 1rem rgba(105, 108, 255, 0.3);
        }
        .materio-metric-value {
          font-size: 2rem;
          font-weight: 700;
          margin-bottom: 0.5rem;
        }
        .materio-metric-label {
          font-size: 0.875rem;
          opacity: 0.9;
        }
      ")
    end

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Language Details", class: "mb-2 text-primary"
          para "View detailed information about this language", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Language", edit_admin_language_path(language), class: "btn btn-primary"
          link_to "Back to Languages", admin_languages_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Language Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-global-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do language.name end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do language.code end
              span class: "badge bg-info fs-6" do language.iso_639_3 end
            end
            if language.notes.present?
              p class: "text-muted mb-0" do language.notes end
            end
          end
        end
      end

      # Language Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Language Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-code-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Language Code" end
                    div class: "fw-semibold" do language.code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-global-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "ISO 639-3 Code" end
                    div class: "fw-semibold" do language.iso_639_3 end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-text text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Script" end
                    div class: "fw-semibold" do language.script end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-arrow-left-right-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Text Direction" end
                    div class: "fw-semibold" do language.direction end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-group-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Language Family" end
                    div class: "fw-semibold" do language.language_family end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do language.id end
                  div class: "materio-metric-label" do "Language ID" end
                end
              end
              if language.notes.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Notes"
                    end
                    div class: "fw-semibold" do language.notes end
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
