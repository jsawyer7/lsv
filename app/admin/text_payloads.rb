ActiveAdmin.register TextPayload do
  permit_params :payload_id, :unit_id, :language, :script, :edition_id, :layer, :content, :meta, :checksum_sha256, :source_id, :license, :version

  # Custom page title
  menu label: "Text Payloads", priority: 12

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Text Payloads Management", class: "mb-2"
      para "Manage text payloads and their content", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Language", class: "form-label"
            input type: "text", name: "q[language_cont]", placeholder: "Search language...", class: "form-control", value: params.dig(:q, :language_cont)
          end
          div class: "col-md-3" do
            label "Script", class: "form-label"
            input type: "text", name: "q[script_cont]", placeholder: "Search script...", class: "form-control", value: params.dig(:q, :script_cont)
          end
          div class: "col-md-3" do
            label "Edition ID", class: "form-label"
            input type: "text", name: "q[edition_id_cont]", placeholder: "Search edition...", class: "form-control", value: params.dig(:q, :edition_id_cont)
          end
          div class: "col-md-3" do
            label "Layer", class: "form-label"
            input type: "text", name: "q[layer_cont]", placeholder: "Search layer...", class: "form-control", value: params.dig(:q, :layer_cont)
          end
        end
        div class: "row g-3 mt-2" do
          div class: "col-md-3" do
            label "Unit ID", class: "form-label"
            input type: "text", name: "q[unit_id_cont]", placeholder: "Search unit ID...", class: "form-control", value: params.dig(:q, :unit_id_cont)
          end
          div class: "col-md-3" do
            label "Source ID", class: "form-label"
            input type: "text", name: "q[source_id_cont]", placeholder: "Search source...", class: "form-control", value: params.dig(:q, :source_id_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterTextPayloads()" do
            "Filter"
          end
          a href: admin_text_payloads_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterTextPayloads() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_text_payloads_path}';

          var language = document.querySelector('input[name=\"q[language_cont]\"]').value;
          var script = document.querySelector('input[name=\"q[script_cont]\"]').value;
          var editionId = document.querySelector('input[name=\"q[edition_id_cont]\"]').value;
          var layer = document.querySelector('input[name=\"q[layer_cont]\"]').value;
          var unitId = document.querySelector('input[name=\"q[unit_id_cont]\"]').value;
          var sourceId = document.querySelector('input[name=\"q[source_id_cont]\"]').value;

          if (language) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[language_cont]';
            input.value = language;
            form.appendChild(input);
          }

          if (script) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[script_cont]';
            input.value = script;
            form.appendChild(input);
          }

          if (editionId) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[edition_id_cont]';
            input.value = editionId;
            form.appendChild(input);
          }

          if (layer) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[layer_cont]';
            input.value = layer;
            form.appendChild(input);
          }

          if (unitId) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[unit_id_cont]';
            input.value = unitId;
            form.appendChild(input);
          }

          if (sourceId) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[source_id_cont]';
            input.value = sourceId;
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
            th "PAYLOAD ID", class: "fw-semibold"
            th "UNIT ID", class: "fw-semibold"
            th "LANGUAGE", class: "fw-semibold"
            th "SCRIPT", class: "fw-semibold"
            th "EDITION ID", class: "fw-semibold"
            th "LAYER", class: "fw-semibold"
            th "CONTENT PREVIEW", class: "fw-semibold"
            th "SOURCE", class: "fw-semibold"
            th "CREATED", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          text_payloads.each do |text_payload|
            tr do
              td do
                link_to text_payload.payload_id, admin_text_payload_path(text_payload), class: "text-decoration-none"
              end
              td do
                if text_payload.text_unit
                  link_to text_payload.unit_id, admin_text_unit_path(text_payload.text_unit), class: "text-decoration-none"
                else
                  text_payload.unit_id
                end
              end
              td text_payload.language
              td text_payload.script
              td text_payload.edition_id
              td text_payload.layer
              td do
                if text_payload.content.present?
                  content_preview = text_payload.content.length > 50 ? "#{text_payload.content[0..50]}..." : text_payload.content
                  span content_preview, title: text_payload.content
                else
                  "N/A"
                end
              end
              td do
                if text_payload.source_registry
                  link_to text_payload.source_id, admin_source_registry_path(text_payload.source_registry), class: "text-decoration-none"
                else
                  text_payload.source_id
                end
              end
              td text_payload.created_at.strftime("%b %d, %Y")
              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_text_payload_path(text_payload)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_text_payload_path(text_payload)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_text_payload_path(text_payload)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end

    div class: "d-flex justify-content-between align-items-center mt-4" do
      div class: "text-muted" do
        "Showing #{text_payloads.count} of #{TextPayload.count} text payloads"
      end
      div do
        link_to "Create New Text Payload", new_admin_text_payload_path, class: "btn btn-primary"
      end
    end
  end

  show do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Text Payload Details", class: "mb-2 text-primary"
          para "View detailed information about this text payload", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Text Payload", edit_admin_text_payload_path(text_payload), class: "btn btn-primary"
          link_to "Back to Text Payloads", admin_text_payloads_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Text Payload Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-file-download-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do text_payload.payload_id end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do text_payload.language end
              span class: "badge bg-secondary fs-6" do text_payload.script end
            end
            para class: "text-muted mb-0" do "#{text_payload.edition_id} - #{text_payload.layer}" end
          end
        end
      end

      # Text Payload Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Text Payload Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-hashtag text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Payload ID" end
                    div class: "fw-semibold" do text_payload.payload_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-file-text-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Unit ID" end
                    div class: "fw-semibold" do text_payload.unit_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-global-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Language" end
                    div class: "fw-semibold" do text_payload.language end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-text text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Script" end
                    div class: "fw-semibold" do text_payload.script end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-book-open-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Edition ID" end
                    div class: "fw-semibold" do text_payload.edition_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-layers-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Layer" end
                    div class: "fw-semibold" do text_payload.layer end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-database-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Source ID" end
                    div class: "fw-semibold" do text_payload.source_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-copyright-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "License" end
                    div class: "fw-semibold" do text_payload.license end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-git-branch-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Version" end
                    div class: "fw-semibold" do text_payload.version || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-calendar-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Created" end
                    div class: "fw-semibold" do text_payload.created_at.strftime("%B %d, %Y") end
                  end
                end
              end
              # Content Section
              if text_payload.content.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Content"
                    end
                    div class: "fw-semibold", style: "white-space: pre-wrap; font-family: inherit; max-height: 200px; overflow-y: auto;" do text_payload.content end
                  end
                end
              end
              # Meta Section
              if text_payload.meta.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-information-line me-1"
                      "Metadata"
                    end
                    div class: "fw-semibold", style: "white-space: pre-wrap; font-family: inherit;" do text_payload.meta end
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
          h1 (f.object.persisted? ? "Edit Text Payload" : "Create Text Payload"), class: "mb-2 text-primary"
          para (f.object.persisted? ? "Update text payload information and settings" : "Create a new text payload"), class: "text-muted mb-0"
        end
        div do
          link_to "Back to Text Payloads", admin_text_payloads_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: (f.object.persisted? ? "ri ri-edit-line me-2" : "ri ri-add-line me-2")
          (f.object.persisted? ? "Text Payload Information" : "New Text Payload Information")
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Payload ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-hashtag me-2"
              span "Payload ID"
            end
            f.input :payload_id,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter unique payload ID"
                    }
          end

          # Unit ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-text-line me-2"
              span "Unit ID"
            end
            f.input :unit_id,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter unit ID"
                    }
          end

          # Language Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Language"
            end
            f.input :language,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter language code (e.g., ara, en)"
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
                      placeholder: "Enter script (e.g., Arab, Latn)"
                    }
          end

          # Edition ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-open-line me-2"
              span "Edition ID"
            end
            f.input :edition_id,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter edition ID"
                    }
          end

          # Layer Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-layers-line me-2"
              span "Layer"
            end
            f.input :layer,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter layer (e.g., source_text)"
                    }
          end

          # Content Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-text-line me-2"
              span "Content"
            end
            f.input :content,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter text content",
                      rows: 5
                    }
          end

          # Meta Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-information-line me-2"
              span "Metadata (Optional)"
            end
            f.input :meta,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter metadata (JSON format)",
                      rows: 3
                    }
          end

          # Source ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-database-line me-2"
              span "Source ID"
            end
            f.input :source_id,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter source ID"
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
                     label: (f.object.persisted? ? "Update Text Payload" : "Create Text Payload"),
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
  filter :language
  filter :script
  filter :edition_id
  filter :layer
  filter :unit_id
  filter :source_id
  filter :license
  filter :created_at
end
