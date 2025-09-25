ActiveAdmin.register FamiliesSeed do
  permit_params :code, :name, :notes

  # Custom page title
  menu label: "Family Seeds", priority: 8

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Family Seeds Management", class: "mb-2"
      para "Manage family seed data and configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-6" do
            label "Name", class: "form-label"
            input type: "text", name: "q[name_cont]", placeholder: "Search name...", class: "form-control", value: params.dig(:q, :name_cont)
          end
          div class: "col-md-6" do
            label "Code", class: "form-label"
            input type: "text", name: "q[code_cont]", placeholder: "Search code...", class: "form-control", value: params.dig(:q, :code_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterSeeds()" do
            "Filter"
          end
          a href: admin_families_seeds_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterSeeds() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_families_seeds_path}';

          var name = document.querySelector('input[name=\"q[name_cont]\"]').value;
          var code = document.querySelector('input[name=\"q[code_cont]\"]').value;

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
            th "NOTES", class: "fw-semibold"
            th "CREATED", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          families_seeds.each do |seed|
            tr do
              # CODE column
              td do
                span class: "text-body fw-semibold" do
                  seed.code
                end
              end

              # NAME column
              td do
                div class: "fw-semibold" do
                  seed.name
                end
              end

              # NOTES column
              td do
                span class: "text-body" do
                  seed.notes.present? ? truncate(seed.notes, length: 30) : "N/A"
                end
              end

              # CREATED column
              td do
                span class: "text-body" do
                  seed.created_at.strftime("%B %d, %Y")
                end
              end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_families_seed_path(seed)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_families_seed_path(seed)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_families_seed_path(seed)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
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
  filter :created_at

  form do |f|

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Edit Family Seed", class: "mb-2 text-primary"
          para "Update family seed information", class: "text-muted mb-0"
        end
        div do
          link_to "Back to Family Seeds", admin_families_seeds_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-edit-line me-2"
          "Seed Information"
        end
      end
      div class: "card-body p-4" do
    f.inputs do
          # Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Seed Code"
            end
            f.input :code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter seed code..."
                    }
          end

          # Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-seedling-line me-2"
              span "Seed Name"
            end
            f.input :name,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter seed name..."
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
                     label: "Update Seed",
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
          h1 "Family Seed Details", class: "mb-2 text-primary"
          para "View detailed information about this family seed", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Seed", edit_admin_families_seed_path(families_seed), class: "btn btn-primary"
          link_to "Back to Family Seeds", admin_families_seeds_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Seed Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-seedling-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do families_seed.name end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do families_seed.code end
            end
            if families_seed.notes.present?
              p class: "text-muted mb-0" do families_seed.notes end
            end
          end
        end
      end

      # Seed Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Seed Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-code-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Seed Code" end
                    div class: "fw-semibold" do families_seed.code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-seedling-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Seed Name" end
                    div class: "fw-semibold" do families_seed.name end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do families_seed.id end
                  div class: "materio-metric-label" do "Seed ID" end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-calendar-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Created" end
                    div class: "fw-semibold" do families_seed.created_at.strftime("%B %d, %Y") end
                  end
                end
              end
              if families_seed.notes.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Notes"
                    end
                    div class: "fw-semibold" do families_seed.notes end
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
