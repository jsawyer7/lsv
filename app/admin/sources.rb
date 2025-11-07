ActiveAdmin.register Source do
  permit_params :code, :name, :description, :language_id, :text_unit_type_id, :rights_json, :provenance

  # Custom page title
  menu parent: "Data Tables", label: "Sources", priority: 3

  # Force custom layout
  controller do
    layout "active_admin_custom"
    
    # Add JSON response for AJAX requests
    def show
      respond_to do |format|
        format.html
        format.json { render json: resource.as_json(include: [:language, :text_unit_type]) }
      end
    end
  end
  
  config.sort_order = 'created_at_asc'

  # Add action items for CRUD operations
  action_item :new_source, only: :index do
    link_to "Add Source", new_admin_source_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Source Management", class: "mb-2"
          para "Manage sources (NA28, Göttingen LXX, MT BHS, KJV, etc.)", class: "text-muted"
        end
        div do
          link_to "Add Source", new_admin_source_path, class: "btn btn-primary"
        end
      end
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "Code", class: "fw-semibold"
            th "Name", class: "fw-semibold"
            th "Language", class: "fw-semibold"
            th "Description", class: "fw-semibold"
            th "Actions", class: "fw-semibold"
          end
        end
        tbody do
          sources.each do |source|
            tr do
              td do
                span class: "badge bg-primary" do source.code end
              end
              td do
                span class: "fw-semibold" do source.name end
              end
              td do
                span class: "badge bg-info" do source.language.name end
              end
              td do
                span class: "text-muted" do source.description || "No description" end
              end
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_source_path(source)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_source_path(source)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_source_path(source)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
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
  filter :language
  filter :description

  form do |f|
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          if f.object.new_record?
            h1 "Create Source", class: "mb-2 text-primary"
            para "Add new source to the system", class: "text-muted mb-0"
          else
            h1 "Edit Source", class: "mb-2 text-primary"
            para "Update source information", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Sources", admin_sources_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-book-line me-2"
          "Source Information"
        end
      end
      div class: "card-body p-5" do
        # Form inputs without numbering
        style do
          raw "ol { list-style: none; counter-reset: none; } ol li { counter-increment: none; } ol li::before { content: none; }"
        end
        f.inputs do
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Source Code"
            end
            f.input :code,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter source code (e.g., NA28, LXX_GOTT, MT_BHS, KJV)..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-line me-2"
              span "Source Name"
            end
            f.input :name,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter source name (e.g., Nestle-Aland 28th edition)..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-translate me-2"
              span "Language"
            end
            f.input :language_id,
                    as: :select,
                    collection: Language.ordered.map { |lang| [lang.display_name, lang.id] },
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Select language..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-check me-2"
              span "Text Unit Type"
            end
            f.input :text_unit_type_id,
                    as: :select,
                    collection: TextUnitType.ordered.map { |type| [type.display_name, type.id] },
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Select text unit type..."
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
                      placeholder: "Enter description (e.g., 'Nestle-Aland 28th edition')...",
                      rows: 3
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-shield-line me-2"
              span "Rights JSON (Optional)"
            end
            f.input :rights_json,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: 'Enter JSON for licensing/rights metadata (e.g., {"license": "CC BY-SA", "attribution": "required"})...',
                      rows: 3
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-history-line me-2"
              span "Provenance (Optional)"
            end
            f.input :provenance,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter source provenance notes...",
                      rows: 2
                    }
          end
        end

        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Source", type: "submit", class: "btn btn-primary"
            else
              button "Update Source", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_sources_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Source: #{resource.name}", class: "mb-1 fw-bold text-dark"
        p "Code: #{resource.code}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Source", edit_admin_source_path(resource), class: "btn btn-primary px-3 py-2"
        link_to "Back to Sources", admin_sources_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-book-line me-2"
              "Source Details"
            end
          end
          div class: "card-body p-4" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-code-line me-2"
                    "Source Code"
                  end
                  div class: "fw-semibold text-dark" do resource.code end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-translate me-2"
                    "Language"
                  end
                  div class: "fw-semibold text-dark" do resource.language.name end
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
              if resource.rights_json.present?
                div class: "col-12" do
                  div class: "materio-info-item" do
                    div class: "text-muted small fw-semibold mb-2" do
                      i class: "ri ri-shield-line me-2"
                      "Rights Information"
                    end
                    div class: "fw-semibold text-dark" do
                      pre class: "bg-light p-2 rounded small" do resource.rights_json end
                    end
                  end
                end
              end
              if resource.provenance.present?
                div class: "col-12" do
                  div class: "materio-info-item" do
                    div class: "text-muted small fw-semibold mb-2" do
                      i class: "ri ri-history-line me-2"
                      "Provenance"
                    end
                    div class: "fw-semibold text-dark" do resource.provenance end
                  end
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
          h6 "Language", class: "mb-2 fw-semibold"
          div class: "fw-bold text-dark mb-2" do resource.language.name end
          p "Source language", class: "text-muted small mb-0"
        end
      end
    end
  end
end
