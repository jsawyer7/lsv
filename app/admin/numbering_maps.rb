ActiveAdmin.register NumberingMap do
  permit_params :numbering_system_id, :unit_id, :work_code, :l1, :l2, :l3, :n_book, :n_chapter, :n_verse, :n_sub, :status

  # Custom page title
  menu label: "Numbering Maps", priority: 9

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Numbering Maps Management", class: "mb-2"
      para "Manage numbering maps and their configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Unit ID", class: "form-label"
            input type: "text", name: "q[unit_id_cont]", placeholder: "Search unit ID...", class: "form-control", value: params.dig(:q, :unit_id_cont)
          end
          div class: "col-md-3" do
            label "Work Code", class: "form-label"
            input type: "text", name: "q[work_code_cont]", placeholder: "Search work code...", class: "form-control", value: params.dig(:q, :work_code_cont)
          end
          div class: "col-md-3" do
            label "Status", class: "form-label"
            input type: "text", name: "q[status_cont]", placeholder: "Search status...", class: "form-control", value: params.dig(:q, :status_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterNumberingMaps()" do
            "Filter"
          end
          a href: admin_numbering_maps_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterNumberingMaps() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_numbering_maps_path}';

          var unitId = document.querySelector('input[name=\"q[unit_id_cont]\"]').value;
          var workCode = document.querySelector('input[name=\"q[work_code_cont]\"]').value;
          var status = document.querySelector('input[name=\"q[status_cont]\"]').value;

          if (unitId) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[unit_id_cont]';
            input.value = unitId;
            form.appendChild(input);
          }

          if (workCode) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[work_code_cont]';
            input.value = workCode;
            form.appendChild(input);
          }

          if (status) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[status_cont]';
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
            th "SYSTEM", class: "fw-semibold"
            th "UNIT ID", class: "fw-semibold"
            th "WORK CODE", class: "fw-semibold"
            th "BOOK", class: "fw-semibold"
            th "CHAPTER", class: "fw-semibold"
            th "VERSE", class: "fw-semibold"
            th "STATUS", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          numbering_maps.each do |numbering_map|
            tr do
              # SYSTEM column
              td do
                span class: "text-body fw-semibold" do
                  numbering_map.numbering_system.name
                end
              end

              # UNIT ID column
              td do
                span class: "badge bg-primary" do
                  numbering_map.unit_id
                end
              end

              # WORK CODE column
              td do
                span class: "text-body fw-semibold" do
                  numbering_map.work_code
                end
              end

              # BOOK column
              td do
                span class: "text-body" do
                  numbering_map.n_book || "N/A"
                end
              end

              # CHAPTER column
              td do
                span class: "text-body" do
                  numbering_map.n_chapter || "N/A"
                end
              end

              # VERSE column
              td do
                span class: "text-body" do
                  numbering_map.n_verse || "N/A"
                end
              end

              # STATUS column
              td do
                if numbering_map.status.present?
                  span class: "badge bg-success" do
                    numbering_map.status
                  end
                else
                  span class: "text-muted" do "N/A" end
                end
              end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_numbering_map_path(numbering_map)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_numbering_map_path(numbering_map)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_numbering_map_path(numbering_map)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :numbering_system
  filter :unit_id
  filter :work_code
  filter :l1
  filter :l2
  filter :l3
  filter :n_book
  filter :n_chapter
  filter :n_verse
  filter :status
  filter :created_at

  form do |f|

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 (f.object.persisted? ? "Edit Numbering Map" : "Create Numbering Map"), class: "mb-2 text-primary"
          para (f.object.persisted? ? "Update numbering map information and settings" : "Create a new numbering map"), class: "text-muted mb-0"
        end
        div do
          link_to "Back to Numbering Maps", admin_numbering_maps_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: (f.object.persisted? ? "ri ri-edit-line me-2" : "ri ri-add-line me-2")
          (f.object.persisted? ? "Numbering Map Information" : "New Numbering Map Information")
        end
      end
      div class: "card-body p-4" do
        f.inputs do
          # Numbering System Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-numbers me-2"
              span "Numbering System"
            end
            f.input :numbering_system_id,
                    as: :select,
                    collection: NumberingSystem.all.map { |ns| [ns.name, ns.id] },
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control"
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
                      placeholder: "Enter unit ID..."
                    }
          end

          # Work Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-open-line me-2"
              span "Work Code"
            end
            f.input :work_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter work code..."
                    }
          end

          # L1, L2, L3 Inputs
          div class: "row" do
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-text me-2"
                  span "L1"
                end
                f.input :l1,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          placeholder: "Enter L1..."
                        }
              end
            end
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-text me-2"
                  span "L2"
                end
                f.input :l2,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          placeholder: "Enter L2..."
                        }
              end
            end
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-text me-2"
                  span "L3"
                end
                f.input :l3,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          placeholder: "Enter L3..."
                        }
              end
            end
          end

          # Numbering Inputs
          div class: "row" do
            div class: "col-md-3" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-book-line me-2"
                  span "Book Number"
                end
                f.input :n_book,
                        as: :number,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          placeholder: "Enter book number..."
                        }
              end
            end
            div class: "col-md-3" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-file-list-line me-2"
                  span "Chapter Number"
                end
                f.input :n_chapter,
                        as: :number,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          placeholder: "Enter chapter number..."
                        }
              end
            end
            div class: "col-md-3" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-file-text-line me-2"
                  span "Verse Number"
                end
                f.input :n_verse,
                        as: :number,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          placeholder: "Enter verse number..."
                        }
              end
            end
            div class: "col-md-3" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-subtract-line me-2"
                  span "Sub Number"
                end
                f.input :n_sub,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          placeholder: "Enter sub number..."
                        }
              end
            end
          end

          # Status Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-checkbox-circle-line me-2"
              span "Status"
            end
            f.input :status,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter status..."
                    }
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: (f.object.persisted? ? "Update Numbering Map" : "Create Numbering Map"),
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
          h1 "Numbering Map Details", class: "mb-2 text-primary"
          para "View detailed information about this numbering map", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Numbering Map", edit_admin_numbering_map_path(numbering_map), class: "btn btn-primary"
          link_to "Back to Numbering Maps", admin_numbering_maps_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Map Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-map-pin-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do numbering_map.unit_id end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do numbering_map.work_code end
              if numbering_map.status.present?
                span class: "badge bg-success fs-6" do numbering_map.status end
              end
            end
          end
        end
      end

      # Map Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Map Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-list-numbers text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Numbering System" end
                    div class: "fw-semibold" do numbering_map.numbering_system.name end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-hashtag text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Unit ID" end
                    div class: "fw-semibold" do numbering_map.unit_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-book-open-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Work Code" end
                    div class: "fw-semibold" do numbering_map.work_code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-checkbox-circle-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Status" end
                    div class: "fw-semibold" do numbering_map.status || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do numbering_map.n_book || "N/A" end
                  div class: "materio-metric-label" do "Book Number" end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do numbering_map.n_chapter || "N/A" end
                  div class: "materio-metric-label" do "Chapter Number" end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do numbering_map.n_verse || "N/A" end
                  div class: "materio-metric-label" do "Verse Number" end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do numbering_map.n_sub || "N/A" end
                  div class: "materio-metric-label" do "Sub Number" end
                end
              end
            end
          end
        end
      end
    end
  end
end
