ActiveAdmin.register FamiliesForFoundation do
  permit_params :code, :name, :domain, :description, :display_order, :is_active

  # Custom page title
  menu label: "Religious Families", priority: 4

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Religious Families Management", class: "mb-2"
      para "Manage religious families and their configurations", class: "text-muted"
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
            label "Domain", class: "form-label"
            input type: "text", name: "q[domain_cont]", placeholder: "Search domain...", class: "form-control", value: params.dig(:q, :domain_cont)
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
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterFamilies()" do
            "Filter"
          end
          a href: admin_families_for_foundations_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterFamilies() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_families_for_foundations_path}';

          var name = document.querySelector('input[name=\"q[name_cont]\"]').value;
          var code = document.querySelector('input[name=\"q[code_cont]\"]').value;
          var domain = document.querySelector('input[name=\"q[domain_cont]\"]').value;
          var status = document.querySelector('select[name=\"q[is_active_eq]\"]').value;

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

          if (domain) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[domain_cont]';
            input.value = domain;
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
            th "NAME", class: "fw-semibold"
            th "DOMAIN", class: "fw-semibold"
            th "ORDER", class: "fw-semibold"
            th "STATUS", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          families_for_foundations.each do |family|
            tr do
              # CODE column
              td do
                span class: "text-body fw-semibold" do
                  family.code
                end
              end

              # NAME column
              td do
                div do
                  div class: "fw-semibold" do
                    family.name
                  end
                  div class: "text-muted small" do
                    truncate(family.description, length: 50) if family.description.present?
                  end
                end
              end

              # DOMAIN column
              td do
                span class: "text-body" do
                  family.domain
                end
              end

              # ORDER column
              td do
                span class: "text-body" do
                  family.display_order
                end
              end

              # STATUS column with badge
              td do
                if family.is_active?
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
                  <a href='#{admin_families_for_foundation_path(family)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_families_for_foundation_path(family)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_families_for_foundation_path(family)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
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
  filter :domain
  filter :is_active
  filter :created_at

  form do |f|

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Edit Religious Family", class: "mb-2 text-primary"
          para "Update religious family information and settings", class: "text-muted mb-0"
        end
        div do
          link_to "Back to Religious Families", admin_families_for_foundations_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-edit-line me-2"
          "Family Information"
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Family Code"
            end
            f.input :code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter family code..."
                    }
          end

          # Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-group-line me-2"
              span "Family Name"
            end
            f.input :name,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter family name..."
                    }
          end

          # Domain Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Domain"
            end
            f.input :domain,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter domain..."
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

          # Display Order Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-ordered me-2"
              span "Display Order"
            end
            f.input :display_order,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter display order...",
                      type: "number"
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
                     label: "Update Family",
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

    # Page Header
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Religious Family Details", class: "mb-2 text-primary"
        para "View detailed information about this religious family", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Family", edit_admin_families_for_foundation_path(families_for_foundation), class: "btn btn-primary"
        link_to "Back to Religious Families", admin_families_for_foundations_path, class: "btn btn-outline-secondary"
      end
    end

    div class: "row g-4" do
      # Left Column - Family Profile
      div class: "col-lg-4" do
        div class: "materio-card" do
          div class: "materio-header" do
            div class: "text-center" do
              div class: "materio-avatar" do
                i class: "ri ri-group-line text-white", style: "font-size: 2rem;"
              end
              h4 class: "mb-1 text-white" do
                families_for_foundation.name
              end
              p class: "text-white-50 mb-0" do
                families_for_foundation.code
              end
            end
          end
          div class: "card-body p-4" do
            div class: "text-center mb-3" do
              span class: "badge bg-#{families_for_foundation.is_active? ? 'success' : 'danger'} fs-6 px-3 py-2" do
                families_for_foundation.is_active? ? "Active" : "Inactive"
              end
            end

            # Action Buttons
            div class: "d-flex gap-2 mt-3" do
              link_to "Edit", edit_admin_families_for_foundation_path(families_for_foundation), class: "btn btn-primary flex-fill"
              link_to "Delete", admin_families_for_foundation_path(families_for_foundation), method: :delete,
                      data: { confirm: "Are you sure you want to delete this family? This action cannot be undone." },
                      class: "btn btn-outline-danger flex-fill"
            end
          end
        end
      end

      # Right Column - Family Information
      div class: "col-lg-8" do
        # Family Information Card
        div class: "materio-card mb-4" do
          div class: "materio-info-card" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-information-line me-2"
              "Family Information"
            end
          end
          div class: "card-body p-4" do
            # Metric-style cards for key information
            div class: "row g-3 mb-4" do
              div class: "col-md-4" do
                div class: "materio-metric-card materio-metric-card-light" do
                  div class: "materio-icon primary" do
                    i class: "ri ri-code-line"
                  end
                  h6 class: "mb-1" do "Code" end
                  h4 class: "mb-0 text-primary" do
                    families_for_foundation.code
                  end
                end
              end
              div class: "col-md-4" do
                div class: "materio-metric-card materio-metric-card-light" do
                  div class: "materio-icon success" do
                    i class: "ri ri-list-ordered"
                  end
                  h6 class: "mb-1" do "Order" end
                  h4 class: "mb-0 text-success" do
                    families_for_foundation.display_order
                  end
                end
              end
              div class: "col-md-4" do
                div class: "materio-metric-card materio-metric-card-light" do
                  div class: "materio-icon #{families_for_foundation.is_active? ? 'success' : 'warning'}" do
                    i class: "ri ri-#{families_for_foundation.is_active? ? 'check-line' : 'close-line'}"
                  end
                  h6 class: "mb-1" do "Status" end
                  h4 class: "mb-0 #{families_for_foundation.is_active? ? 'text-success' : 'text-warning'}" do
                    families_for_foundation.is_active? ? "Active" : "Inactive"
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
                    "Domain"
                  end
                  div class: "fw-bold text-dark" do
                    families_for_foundation.domain
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "fw-semibold text-muted mb-1" do
                    i class: "ri ri-group-line me-2"
                    "Family Name"
                  end
                  div class: "fw-bold text-dark" do
                    families_for_foundation.name
                  end
                end
              end
            end

            # Description
            if families_for_foundation.description.present?
              div class: "mt-3" do
                div class: "materio-info-item" do
                  div class: "fw-semibold text-muted mb-2" do
                    i class: "ri ri-file-text-line me-2"
                    "Description"
                  end
                  div class: "text-dark" do
                    families_for_foundation.description
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
