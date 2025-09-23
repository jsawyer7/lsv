ActiveAdmin.register NumberingSystem do
  permit_params :code, :name, :description

  # Custom page title
  menu label: "Numbering Systems", priority: 7

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Numbering Systems Management", class: "mb-2"
      para "Manage numbering systems and their configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Code", class: "form-label"
            input type: "text", name: "q[code_cont]", placeholder: "Search code...", class: "form-control", value: params.dig(:q, :code_cont)
          end
          div class: "col-md-3" do
            label "Name", class: "form-label"
            input type: "text", name: "q[name_cont]", placeholder: "Search name...", class: "form-control", value: params.dig(:q, :name_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterNumberingSystems()" do
            "Filter"
          end
          a href: admin_numbering_systems_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterNumberingSystems() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_numbering_systems_path}';

          var code = document.querySelector('input[name=\"q[code_cont]\"]').value;
          var name = document.querySelector('input[name=\"q[name_cont]\"]').value;

          if (code) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[code_cont]';
            input.value = code;
            form.appendChild(input);
          }

          if (name) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[name_cont]';
            input.value = name;
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
            th "DESCRIPTION", class: "fw-semibold"
            th "LABELS COUNT", class: "fw-semibold"
            th "MAPS COUNT", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          numbering_systems.each do |numbering_system|
            tr do
              # CODE column
              td do
                span class: "text-body fw-semibold" do
                  numbering_system.code
                end
              end

              # NAME column
              td do
                div class: "fw-semibold" do
                  numbering_system.name
                end
              end

              # DESCRIPTION column
              td do
                span class: "text-body" do
                  numbering_system.description&.truncate(50) || "N/A"
                end
              end

              # LABELS COUNT column
              td do
                span class: "badge bg-info" do
                  numbering_system.numbering_labels.count
                end
              end

              # MAPS COUNT column
              td do
                span class: "badge bg-success" do
                  numbering_system.numbering_maps.count
                end
              end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_numbering_system_path(numbering_system)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_numbering_system_path(numbering_system)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_numbering_system_path(numbering_system)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
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
  filter :created_at

  form do |f|

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Edit Numbering System", class: "mb-2 text-primary"
          para "Update numbering system information and settings", class: "text-muted mb-0"
        end
        div do
          link_to "Back to Numbering Systems", admin_numbering_systems_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-edit-line me-2"
          "Numbering System Information"
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "System Code"
            end
            f.input :code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter system code..."
                    }
          end

          # Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-open-line me-2"
              span "System Name"
            end
            f.input :name,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter system name..."
                    }
          end

          # Description Input
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
                      placeholder: "Enter description...",
                      rows: 4
                    }
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: "Update Numbering System",
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
          h1 "Numbering System Details", class: "mb-2 text-primary"
          para "View detailed information about this numbering system", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Numbering System", edit_admin_numbering_system_path(numbering_system), class: "btn btn-primary"
          link_to "Back to Numbering Systems", admin_numbering_systems_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # System Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-list-numbers text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do numbering_system.name end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do numbering_system.code end
            end
            if numbering_system.description.present?
              p class: "text-muted mb-0" do numbering_system.description end
            end
          end
        end
      end

      # System Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "System Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-code-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "System Code" end
                    div class: "fw-semibold" do numbering_system.code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-book-open-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "System Name" end
                    div class: "fw-semibold" do numbering_system.name end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do numbering_system.numbering_labels.count end
                  div class: "materio-metric-label" do "Labels Count" end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do numbering_system.numbering_maps.count end
                  div class: "materio-metric-label" do "Maps Count" end
                end
              end
              if numbering_system.description.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Description"
                    end
                    div class: "fw-semibold" do numbering_system.description end
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
