ActiveAdmin.register Canon do
  permit_params :code, :name, :domain_code, :description, :is_official, :display_order

  # Custom page title
  menu label: "Canons", priority: 9

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Canons Management", class: "mb-2"
      para "Manage religious canons and their configurations", class: "text-muted"
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
            input type: "text", name: "q[domain_code_cont]", placeholder: "Search domain...", class: "form-control", value: params.dig(:q, :domain_code_cont)
          end
          div class: "col-md-3" do
            label "Status", class: "form-label"
            select name: "q[is_official_eq]", class: "form-select" do
              option "All Status", value: ""
              option "Official", value: "true", selected: params.dig(:q, :is_official_eq) == "true"
              option "Unofficial", value: "false", selected: params.dig(:q, :is_official_eq) == "false"
            end
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterCanons()" do
            "Filter"
          end
          a href: admin_canons_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterCanons() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_canons_path}';

          var name = document.querySelector('input[name=\"q[name_cont]\"]').value;
          var code = document.querySelector('input[name=\"q[code_cont]\"]').value;
          var domain = document.querySelector('input[name=\"q[domain_code_cont]\"]').value;
          var status = document.querySelector('select[name=\"q[is_official_eq]\"]').value;

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
            input.name = 'q[domain_code_cont]';
            input.value = domain;
            form.appendChild(input);
          }

          if (status && status !== 'All Status') {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[is_official_eq]';
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
            th "STATUS", class: "fw-semibold"
            th "ORDER", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          canons.each do |canon|
            tr do
              # CODE column
              td do
                span class: "text-body fw-semibold" do
                  canon.code
                end
              end

              # NAME column
              td do
                div do
                  div class: "fw-semibold" do
                    canon.name
                  end
                  div class: "text-muted small" do
                    truncate(canon.description, length: 50) if canon.description.present?
                  end
                end
              end

              # DOMAIN column
              td do
                span class: "text-body" do
                  canon.domain_code
                end
              end

              # STATUS column with badge
              td do
                if canon.is_official?
                  span class: "badge bg-success" do
                    "Official"
                  end
                else
                  span class: "badge bg-warning" do
                    "Unofficial"
                  end
                end
              end

              # ORDER column
              td do
                span class: "text-body" do
                  canon.display_order
    end
  end

              # ACTIONS column
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

  filter :name
  filter :code
  filter :domain_code
  filter :is_official
  filter :created_at

  form do |f|

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Edit Canon", class: "mb-2 text-primary"
          para "Update canon information and settings", class: "text-muted mb-0"
        end
        div do
          link_to "Back to Canons", admin_canons_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-edit-line me-2"
          "Canon Information"
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Canon Code"
            end
            f.input :code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter canon code..."
                    }
          end

          # Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-line me-2"
              span "Canon Name"
            end
            f.input :name,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter canon name..."
                    }
          end

          # Domain Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Domain Code"
            end
            f.input :domain_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter domain code..."
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

          # Official Status
          div class: "materio-form-group" do
            div class: "d-flex align-items-center mb-2" do
              i class: "ri ri-shield-check-line me-2"
              span "Official Status"
            end
            div class: "form-check form-switch" do
              f.check_box :is_official,
                         class: "form-check-input",
                         role: "switch"
            end
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: "Update Canon",
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
          h1 "Canon Details", class: "mb-2 text-primary"
          para "View detailed information about this canon", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Canon", edit_admin_canon_path(canon), class: "btn btn-primary"
          link_to "Back to Canons", admin_canons_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Canon Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-book-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do canon.name end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do canon.code end
              span class: "badge bg-#{canon.is_official? ? 'success' : 'warning'} fs-6" do
                canon.is_official? ? "Official" : "Unofficial"
              end
            end
            if canon.description.present?
              p class: "text-muted mb-0" do canon.description end
            end
          end
        end
      end

      # Canon Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Canon Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-code-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Canon Code" end
                    div class: "fw-semibold" do canon.code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-global-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Domain Code" end
                    div class: "fw-semibold" do canon.domain_code || "Not specified" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-shield-check-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Status" end
                    div class: "fw-semibold" do
                      if canon.is_official?
                        span class: "text-success" do "Official Canon" end
                      else
                        span class: "text-warning" do "Unofficial Canon" end
                      end
                    end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-list-ordered text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Display Order" end
                    div class: "fw-semibold" do canon.display_order || "Not set" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do canon.canon_book_inclusions.count end
                  div class: "materio-metric-label" do "Book Inclusions" end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do canon.canon_work_preferences.count end
                  div class: "materio-metric-label" do "Work Preferences" end
                end
              end
              if canon.description.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Description"
                    end
                    div class: "fw-semibold" do canon.description end
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
