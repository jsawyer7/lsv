ActiveAdmin.register SourceRegistry do
  permit_params :source_id, :name, :publisher, :contact, :license, :url, :version, :checksum_sha256, :notes

  # Custom page title
  menu label: "Source Registries", priority: 13

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Source Registries Management", class: "mb-2"
      para "Manage source registries and their information", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-4" do
            label "Name", class: "form-label"
            input type: "text", name: "q[name_cont]", placeholder: "Search name...", class: "form-control", value: params.dig(:q, :name_cont)
          end
          div class: "col-md-4" do
            label "Publisher", class: "form-label"
            input type: "text", name: "q[publisher_cont]", placeholder: "Search publisher...", class: "form-control", value: params.dig(:q, :publisher_cont)
          end
          div class: "col-md-4" do
            label "License", class: "form-label"
            input type: "text", name: "q[license_cont]", placeholder: "Search license...", class: "form-control", value: params.dig(:q, :license_cont)
          end
        end
        div class: "row g-3 mt-2" do
          div class: "col-md-4" do
            label "Version", class: "form-label"
            input type: "text", name: "q[version_cont]", placeholder: "Search version...", class: "form-control", value: params.dig(:q, :version_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterSourceRegistries()" do
            "Filter"
          end
          a href: admin_source_registries_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterSourceRegistries() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_source_registries_path}';

          var name = document.querySelector('input[name=\"q[name_cont]\"]').value;
          var publisher = document.querySelector('input[name=\"q[publisher_cont]\"]').value;
          var license = document.querySelector('input[name=\"q[license_cont]\"]').value;
          var version = document.querySelector('input[name=\"q[version_cont]\"]').value;

          if (name) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[name_cont]';
            input.value = name;
            form.appendChild(input);
          }

          if (publisher) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[publisher_cont]';
            input.value = publisher;
            form.appendChild(input);
          }

          if (license) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[license_cont]';
            input.value = license;
            form.appendChild(input);
          }

          if (version) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[version_cont]';
            input.value = version;
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
            th "SOURCE ID", class: "fw-semibold"
            th "NAME", class: "fw-semibold"
            th "PUBLISHER", class: "fw-semibold"
            th "LICENSE", class: "fw-semibold"
            th "VERSION", class: "fw-semibold"
            th "TEXT PAYLOADS", class: "fw-semibold"
            th "CREATED", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          source_registries.each do |source_registry|
            tr do
              td do
                link_to source_registry.source_id, admin_source_registry_path(source_registry), class: "text-decoration-none"
              end
              td source_registry.name
              td source_registry.publisher || "N/A"
              td source_registry.license
              td source_registry.version || "N/A"
              td do
                span class: "badge bg-info" do source_registry.text_payloads.count end
              end
              td source_registry.created_at.strftime("%b %d, %Y")
              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_source_registry_path(source_registry)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_source_registry_path(source_registry)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_source_registry_path(source_registry)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end

    div class: "d-flex justify-content-between align-items-center mt-4" do
      div class: "text-muted" do
        "Showing #{source_registries.count} of #{SourceRegistry.count} source registries"
      end
      div do
        link_to "Create New Source Registry", new_admin_source_registry_path, class: "btn btn-primary"
      end
    end
  end

  show do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Source Registry Details", class: "mb-2 text-primary"
          para "View detailed information about this source registry", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Source Registry", edit_admin_source_registry_path(source_registry), class: "btn btn-primary"
          link_to "Back to Source Registries", admin_source_registries_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Source Registry Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-database-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do source_registry.source_id end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do source_registry.name end
            end
            para class: "text-muted mb-0" do source_registry.publisher || "No publisher specified" end
          end
        end
      end

      # Source Registry Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Source Registry Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-hashtag text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Source ID" end
                    div class: "fw-semibold" do source_registry.source_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-bookmark-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Name" end
                    div class: "fw-semibold" do source_registry.name end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-building-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Publisher" end
                    div class: "fw-semibold" do source_registry.publisher || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-contacts-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Contact" end
                    div class: "fw-semibold" do source_registry.contact || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-copyright-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "License" end
                    div class: "fw-semibold" do source_registry.license end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-git-branch-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Version" end
                    div class: "fw-semibold" do source_registry.version || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-links-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "URL" end
                    div class: "fw-semibold" do
                      if source_registry.url.present?
                        link_to source_registry.url, source_registry.url, target: "_blank", class: "text-decoration-none"
                      else
                        "N/A"
                      end
                    end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-calendar-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Created" end
                    div class: "fw-semibold" do source_registry.created_at.strftime("%B %d, %Y") end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  form do |f|
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 (f.object.persisted? ? "Edit Source Registry" : "Create Source Registry"), class: "mb-2 text-primary"
          para (f.object.persisted? ? "Update source registry information and settings" : "Create a new source registry"), class: "text-muted mb-0"
        end
        div do
          link_to "Back to Source Registries", admin_source_registries_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: (f.object.persisted? ? "ri ri-edit-line me-2" : "ri ri-add-line me-2")
          (f.object.persisted? ? "Source Registry Information" : "New Source Registry Information")
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Source ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-hashtag me-2"
              span "Source ID"
            end
            f.input :source_id,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter unique source ID"
                    }
          end

          # Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-bookmark-line me-2"
              span "Name"
            end
            f.input :name,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter source name"
                    }
          end

          # Publisher Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-building-line me-2"
              span "Publisher (Optional)"
            end
            f.input :publisher,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter publisher name"
                    }
          end

          # Contact Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-contacts-line me-2"
              span "Contact (Optional)"
            end
            f.input :contact,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter contact information"
                    }
          end

          # License Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-copyright-line me-2"
              span "License"
            end
            f.input :license,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter license (e.g., CC BY 3.0)"
                    }
          end

          # URL Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-links-line me-2"
              span "URL (Optional)"
            end
            f.input :url,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter URL"
                    }
          end

          # Version Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-git-branch-line me-2"
              span "Version (Optional)"
            end
            f.input :version,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter version"
                    }
          end

        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: (f.object.persisted? ? "Update Source Registry" : "Create Source Registry"),
                     class: "materio-btn-primary"
            f.action :cancel,
                     label: "Cancel",
                     class: "materio-btn-secondary"
          end
        end
      end
    end
  end

  # Filters
  filter :name
  filter :publisher
  filter :license
  filter :version
  filter :created_at
end
