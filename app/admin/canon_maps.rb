ActiveAdmin.register CanonMap do
  permit_params :canon_id, :unit_id, :sequence_index

  # Override default ordering since canon_maps doesn't have an 'id' column
  config.sort_order = 'canon_id_desc'

  # Custom page title
  menu label: "Canon Maps", priority: 11

  # Force custom layout
  controller do
    layout "active_admin_custom"

    # Custom finder for composite primary key
    def find_resource
      if params[:id].present?
        CanonMap.find_by_param(params[:id])
      else
        super
      end
    end
  end

  index do
    div class: "page-header mb-4" do
      h1 "Canon Maps Management", class: "mb-2"
      para "Manage canon maps and their configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-4" do
            label "Canon ID", class: "form-label"
            input type: "text", name: "q[canon_id_cont]", placeholder: "Search canon ID...", class: "form-control", value: params.dig(:q, :canon_id_cont)
          end
          div class: "col-md-4" do
            label "Unit ID", class: "form-label"
            input type: "text", name: "q[unit_id_cont]", placeholder: "Search unit ID...", class: "form-control", value: params.dig(:q, :unit_id_cont)
          end
          div class: "col-md-4" do
            label "Sequence Index", class: "form-label"
            input type: "number", name: "q[sequence_index_eq]", placeholder: "Sequence index...", class: "form-control", value: params.dig(:q, :sequence_index_eq)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterCanonMaps()" do
            "Filter"
          end
          a href: admin_canon_maps_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterCanonMaps() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_canon_maps_path}';

          var canonId = document.querySelector('input[name=\"q[canon_id_cont]\"]').value;
          var unitId = document.querySelector('input[name=\"q[unit_id_cont]\"]').value;
          var sequenceIndex = document.querySelector('input[name=\"q[sequence_index_eq]\"]').value;

          if (canonId) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[canon_id_cont]';
            input.value = canonId;
            form.appendChild(input);
          }

          if (unitId) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[unit_id_cont]';
            input.value = unitId;
            form.appendChild(input);
          }

          if (sequenceIndex) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[sequence_index_eq]';
            input.value = sequenceIndex;
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
            th "CANON ID", class: "fw-semibold"
            th "UNIT ID", class: "fw-semibold"
            th "SEQUENCE INDEX", class: "fw-semibold"
            th "TEXT UNIT", class: "fw-semibold"
            th "CREATED", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          canon_maps.each do |canon_map|
            tr do
              td do
                link_to canon_map.canon_id, admin_canon_map_path(canon_map), class: "text-decoration-none"
              end
              td canon_map.unit_id
              td canon_map.sequence_index
              td do
                if canon_map.text_unit
                  link_to canon_map.text_unit.unit_id, admin_text_unit_path(canon_map.text_unit), class: "text-decoration-none"
                else
                  "N/A"
                end
              end
              td canon_map.created_at.strftime("%b %d, %Y")
              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_canon_map_path(canon_map)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_canon_map_path(canon_map)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_canon_map_path(canon_map)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end

    div class: "d-flex justify-content-between align-items-center mt-4" do
      div class: "text-muted" do
        "Showing #{canon_maps.count} of #{CanonMap.count} canon maps"
      end
      div do
        link_to "Create New Canon Map", new_admin_canon_map_path, class: "btn btn-primary"
      end
    end
  end

  show do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Canon Map Details", class: "mb-2 text-primary"
          para "View detailed information about this canon map", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Canon Map", edit_admin_canon_map_path(canon_map), class: "btn btn-primary"
          link_to "Back to Canon Maps", admin_canon_maps_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Canon Map Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-map-pin-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do canon_map.canon_id end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do "Sequence #{canon_map.sequence_index}" end
            end
            para class: "text-muted mb-0" do canon_map.unit_id end
          end
        end
      end

      # Canon Map Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Canon Map Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-list-numbers text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Canon ID" end
                    div class: "fw-semibold" do canon_map.canon_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-hashtag text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Unit ID" end
                    div class: "fw-semibold" do canon_map.unit_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do canon_map.sequence_index end
                  div class: "materio-metric-label" do "Sequence Index" end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-calendar-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Created" end
                    div class: "fw-semibold" do canon_map.created_at.strftime("%B %d, %Y") end
                  end
                end
              end
              # Related Text Unit Information
              if canon_map.text_unit
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Related Text Unit"
                    end
                    div class: "row g-2" do
                      div class: "col-md-6" do
                        div class: "fw-semibold" do "Tradition: #{canon_map.text_unit.tradition}" end
                      end
                      div class: "col-md-6" do
                        div class: "fw-semibold" do "Work: #{canon_map.text_unit.work_code}" end
                      end
                      div class: "col-md-6" do
                        div class: "fw-semibold" do "Chapter: #{canon_map.text_unit.chapter}" end
                      end
                      div class: "col-md-6" do
                        div class: "fw-semibold" do "Verse: #{canon_map.text_unit.verse}" end
                      end
                    end
                    div class: "mt-2" do
                      link_to "View Full Text Unit Details", admin_text_unit_path(canon_map.text_unit), class: "btn btn-outline-primary btn-sm"
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

  form do |f|
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 (f.object.persisted? ? "Edit Canon Map" : "Create Canon Map"), class: "mb-2 text-primary"
          para (f.object.persisted? ? "Update canon map information and settings" : "Create a new canon map"), class: "text-muted mb-0"
        end
        div do
          link_to "Back to Canon Maps", admin_canon_maps_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: (f.object.persisted? ? "ri ri-edit-line me-2" : "ri ri-add-line me-2")
          (f.object.persisted? ? "Canon Map Information" : "New Canon Map Information")
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Canon ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-numbers me-2"
              span "Canon ID"
            end
            f.input :canon_id,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter canon ID"
                    }
          end

          # Unit ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-hashtag me-2"
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

          # Sequence Index Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-ordered me-2"
              span "Sequence Index"
            end
            f.input :sequence_index,
                    as: :number,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter sequence index",
                      min: 1
                    }
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: (f.object.persisted? ? "Update Canon Map" : "Create Canon Map"),
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
  filter :canon_id
  filter :unit_id
  filter :sequence_index
  filter :created_at
end
