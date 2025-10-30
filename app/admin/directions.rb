ActiveAdmin.register Direction do
  permit_params :code, :name, :description
  menu parent: "Data Tables", label: "Directions", priority: 1
  controller { layout "active_admin_custom" }

  action_item :new_direction, only: :index do
    link_to "Add Direction", new_admin_direction_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Direction Management", class: "mb-2"
          para "Manage text directions (LTR, RTL)", class: "text-muted"
        end
        div do
          link_to "Add Direction", new_admin_direction_path, class: "btn btn-primary"
        end
      end
    end

    table class: "table table-striped table-hover" do
      thead class: "table-dark" do
        tr do
          th "Code"
          th "Name"
          th "Description"
          th "Languages"
          th "Actions", class: "text-end"
        end
      end
      tbody do
        directions.each do |direction|
          tr do
            td do
              span class: "badge bg-primary" do direction.code end
            end
            td do
              span class: "fw-semibold" do direction.name end
            end
            td do
              span class: "text-muted" do direction.description || "No description" end
            end
            td do
              span class: "badge bg-info" do direction.languages.count end
            end
            td class: "text-end" do
              div class: "btn-group" do
                link_to "View", admin_direction_path(direction), class: "btn btn-sm btn-outline-primary"
                link_to "Edit", edit_admin_direction_path(direction), class: "btn btn-sm btn-outline-secondary"
              end
            end
          end
        end
      end
    end
  end

  form do |f|
    div class: "card" do
      div class: "card-header bg-primary text-white" do
        div class: "d-flex justify-content-between align-items-center" do
          div do
            h4 class: "mb-0" do
              if f.object.new_record?
                "Create Direction"
              else
                "Edit Direction"
              end
            end
            p class: "mb-0 opacity-75" do
              if f.object.new_record?
                "Add new text direction"
              else
                "Update direction information"
              end
            end
          end
          link_to "Back to Directions", admin_directions_path, class: "btn btn-light"
        end
      end

      div class: "card-body p-5" do
        style do
          raw "ol { list-style: none; counter-reset: none; } ol li { counter-increment: none; } ol li::before { content: none; }"
        end
        f.inputs do
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Direction Code"
            end
            f.input :code,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter direction code (e.g., LTR, RTL)..."
                    }
          end
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-text-direction-l me-2"
              span "Direction Name"
            end
            f.input :name,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter direction name (e.g., Left-to-Right, Right-to-Left)..."
                    }
          end
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
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter description...",
                      rows: 3
                    }
          end
        end
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Direction", type: "submit", class: "btn btn-primary"
            else
              button "Update Direction", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_directions_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Direction: #{resource.name}", class: "mb-1 fw-bold text-dark"
        p "Code: #{resource.code}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Direction", edit_admin_direction_path(resource), class: "btn btn-primary px-3 py-2"
        link_to "Back to Directions", admin_directions_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-text-direction-l me-2"
              "Direction Details"
            end
          end
          div class: "card-body p-4" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-code-line me-2"
                    "Direction Code"
                  end
                  div class: "fw-semibold text-dark" do resource.code end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-text-direction-l me-2"
                    "Direction Name"
                  end
                  div class: "fw-semibold text-dark" do resource.name end
                end
              end
              div class: "col-12" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-file-text-line me-2"
                    "Description"
                  end
                  div class: "fw-semibold text-dark" do resource.description || "No description provided" end
                end
              end
            end
          end
        end
      end
      div class: "col-lg-4" do
        div class: "materio-metric-card materio-metric-card-light" do
          div class: "materio-icon primary" do
            i class: "ri ri-translate"
          end
          h6 "Languages", class: "mb-2 fw-semibold"
          div class: "fw-bold text-dark mb-2" do resource.languages.count end
          p "Languages using this direction", class: "text-muted small mb-0"
        end
      end
    end
  end
end
