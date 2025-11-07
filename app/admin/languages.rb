ActiveAdmin.register Language do
  permit_params :code, :name, :description, :direction_id, :script, :font_stack,
                :has_joining, :uses_diacritics, :has_cantillation, :has_ayah_markers,
                :native_digits, :unicode_normalization, :shaping_engine, :punctuation_mirroring

  # Custom page title
  menu parent: "Data Tables", label: "Languages", priority: 2

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end
  
  config.sort_order = 'created_at_asc'

  # Add action items for CRUD operations
  action_item :new_language, only: :index do
    link_to "Add Language", new_admin_language_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Language Management", class: "mb-2"
          para "Manage languages used in sources", class: "text-muted"
        end
        div do
          link_to "Add Language", new_admin_language_path, class: "btn btn-primary"
        end
      end
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "Code", class: "fw-semibold"
            th "Name", class: "fw-semibold"
            th "Description", class: "fw-semibold"
            th "Sources Count", class: "fw-semibold"
            th "Actions", class: "fw-semibold"
          end
        end
        tbody do
          languages.each do |language|
            tr do
              td do
                span class: "badge bg-primary" do language.code end
              end
              td do
                span class: "fw-semibold" do language.name end
              end
              td do
                span class: "text-muted" do language.description || "No description" end
              end
              td do
                span class: "badge bg-info" do language.sources.count end
              end
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_language_path(language)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_language_path(language)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_language_path(language)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
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

  form do |f|
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          if f.object.new_record?
            h1 "Create Language", class: "mb-2 text-primary"
            para "Add new language to the system", class: "text-muted mb-0"
          else
            h1 "Edit Language", class: "mb-2 text-primary"
            para "Update language information", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Languages", admin_languages_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-translate me-2"
          "Language Information"
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
              span "Language Code"
            end
            f.input :code,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter language code (e.g., grc, heb, eng, gez)..."
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-translate me-2"
              span "Language Name"
            end
            f.input :name,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter language name (e.g., Greek, Hebrew, English, Ge'ez)..."
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
                      placeholder: "Enter description (e.g., 'Koine Greek, NT manuscripts')...",
                      rows: 3
                    }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-text-direction-l me-2"
              span "Direction"
            end
            f.input :direction_id,
                    as: :select,
                    collection: Direction.ordered.map { |dir| [dir.display_name, dir.id] },
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;"
                    }
          end

          div class: "row" do
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-font-size me-2"
                  span "Script"
                end
                f.input :script,
                        as: :string,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;",
                          placeholder: "e.g., Arabic, Hebrew, Greek, Ethiopic..."
                        }
              end
            end
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-font-sans me-2"
                  span "Font Stack"
                end
                f.input :font_stack,
                        as: :text,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;",
                          placeholder: "e.g., 'SBL Hebrew, Ezra SIL, serif'",
                          rows: 2
                        }
              end
            end
          end

          div class: "row" do
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-text me-2"
                  span "Unicode Normalization"
                end
                f.input :unicode_normalization,
                        as: :select,
                        collection: [['NFC', 'NFC'], ['NFD', 'NFD'], ['NFKC', 'NFKC'], ['NFKD', 'NFKD']],
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;"
                        }
              end
            end
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-shape me-2"
                  span "Shaping Engine"
                end
                f.input :shaping_engine,
                        as: :string,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;",
                          placeholder: "e.g., HarfBuzz, ICU..."
                        }
              end
            end
          end

          # Script-specific features checkboxes
          div class: "materio-form-group" do
            div class: "materio-form-label mb-3" do
              i class: "ri ri-settings-3 me-2"
              span "Script-Specific Features"
            end
            div class: "row" do
              div class: "col-md-6" do
                div class: "form-check" do
                  f.check_box :has_joining, class: "form-check-input"
                  f.label :has_joining, "Has Joining (Arabic, Syriac)", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :uses_diacritics, class: "form-check-input"
                  f.label :uses_diacritics, "Uses Diacritics (Arabic, Hebrew, Greek)", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :has_cantillation, class: "form-check-input"
                  f.label :has_cantillation, "Has Cantillation (Hebrew)", class: "form-check-label"
                end
              end
              div class: "col-md-6" do
                div class: "form-check" do
                  f.check_box :has_ayah_markers, class: "form-check-input"
                  f.label :has_ayah_markers, "Has Ayah Markers (Quran)", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :native_digits, class: "form-check-input"
                  f.label :native_digits, "Uses Native Digits (Arabic-Indic)", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :punctuation_mirroring, class: "form-check-input"
                  f.label :punctuation_mirroring, "Punctuation Mirroring (RTL)", class: "form-check-label"
                end
              end
            end
          end
        end

        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Language", type: "submit", class: "btn btn-primary"
            else
              button "Update Language", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_languages_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Language: #{language.name}", class: "mb-1 fw-bold text-dark"
        p "Code: #{language.code}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Language", edit_admin_language_path(language), class: "btn btn-primary px-3 py-2"
        link_to "Back to Languages", admin_languages_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-translate me-2"
              "Language Details"
            end
          end
          div class: "card-body p-4" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-code-line me-2"
                    "Language Code"
                  end
                  div class: "fw-semibold text-dark" do language.code end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-translate me-2"
                    "Language Name"
                  end
                  div class: "fw-semibold text-dark" do language.name end
                end
              end
              div class: "col-12" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-file-text-line me-2"
                    "Description"
                  end
                  div class: "fw-semibold text-dark" do language.description || "No description provided" end
                end
              end
            end
          end
        end
      end

      div class: "col-lg-4" do
        div class: "materio-metric-card materio-metric-card-light" do
          div class: "materio-icon primary" do
            i class: "ri ri-book-line"
          end
          h6 "Sources Count", class: "mb-2 fw-semibold"
          div class: "fw-bold text-dark mb-2" do language.sources.count end
          p "Sources using this language", class: "text-muted small mb-0"
        end
      end
    end

    if language.sources.any?
      div class: "row mt-4" do
        div class: "col-12" do
          div class: "materio-card" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-book-line me-2"
                "Sources in this Language"
              end
            end
            div class: "card-body p-4" do
              div class: "table-responsive" do
                table class: "table table-sm" do
                  thead do
                    tr do
                      th "Code"
                      th "Name"
                      th "Description"
                    end
                  end
                  tbody do
                    language.sources.ordered.each do |source|
                      tr do
                        td do
                          span class: "badge bg-secondary" do source.code end
                        end
                        td do
                          link_to source.name, admin_source_path(source), class: "text-decoration-none"
                        end
                        td do
                          span class: "text-muted small" do source.description || "No description" end
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
    end
  end
end
