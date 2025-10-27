ActiveAdmin.register TextContent do
  permit_params :source_id, :book_id, :text_unit_type_id, :language_id, :parent_unit_id,
                :chapter_number, :verse_number, :unit_number, :content, :unit_key,
                :canon_catholic, :canon_protestant, :canon_lutheran, :canon_anglican,
                :canon_greek_orthodox, :canon_russian_orthodox, :canon_georgian_orthodox,
                :canon_western_orthodox, :canon_coptic, :canon_armenian, :canon_ethiopian,
                :canon_syriac, :canon_church_east, :canon_judaic, :canon_samaritan,
                :canon_lds, :canon_quran
  menu label: "Text Contents", priority: 11
  controller { layout "active_admin_custom" }

  action_item :new_text_content, only: :index do
    link_to "Add Text Content", new_admin_text_content_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Text Content Management", class: "mb-2"
          para "Manage text content with canon assignments", class: "text-muted"
        end
        div do
          link_to "Add Text Content", new_admin_text_content_path, class: "btn btn-primary"
        end
      end
    end

    table class: "table table-striped table-hover" do
      thead class: "table-dark" do
        tr do
          th "Unit Key"
          th "Source"
          th "Book"
          th "Type"
          th "Content Preview"
          th "Canons"
          th "Actions", class: "text-end"
        end
      end
      tbody do
        text_contents.each do |text_content|
          tr do
            td do
              span class: "badge bg-primary" do text_content.unit_key end
            end
            td do
              span class: "fw-semibold" do text_content.source.name end
            end
            td do
              span class: "fw-semibold" do text_content.book.std_name end
            end
            td do
              span class: "badge bg-info" do text_content.text_unit_type.name end
            end
            td do
              span class: "text-muted" do truncate(text_content.content, length: 50) end
            end
            td do
              span class: "badge bg-success" do text_content.canon_list.present? ? text_content.canon_list.split(", ").first : "None" end
            end
            td class: "text-end" do
              div class: "btn-group" do
                link_to "View", admin_text_content_path(text_content), class: "btn btn-sm btn-outline-primary"
                link_to "Edit", edit_admin_text_content_path(text_content), class: "btn btn-sm btn-outline-secondary"
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
                "Create Text Content"
              else
                "Edit Text Content"
              end
            end
            p class: "mb-0 opacity-75" do
              if f.object.new_record?
                "Add new text content"
              else
                "Update text content information"
              end
            end
          end
          link_to "Back to Text Contents", admin_text_contents_path, class: "btn btn-light"
        end
      end

      div class: "card-body p-5" do
        style do
          raw "ol { list-style: none; counter-reset: none; } ol li { counter-increment: none; } ol li::before { content: none; }"
        end
        f.inputs do
          div class: "row" do
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-book-line me-2"
                  span "Source"
                end
                f.input :source_id,
                        as: :select,
                        collection: Source.ordered.map { |source| [source.display_name, source.id] },
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
                  i class: "ri ri-book-open-line me-2"
                  span "Book"
                end
                f.input :book_id,
                        as: :select,
                        collection: Book.ordered.map { |book| [book.display_name, book.id] },
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;"
                        }
              end
            end
          end
          
          div class: "row" do
            div class: "col-md-6" do
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
                          style: "width: 100%; max-width: 500px;"
                        }
              end
            end
            div class: "col-md-6" do
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
                          style: "width: 100%; max-width: 500px;"
                        }
              end
            end
          end

          div class: "row" do
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-sort-asc me-2"
                  span "Chapter Number"
                end
                f.input :chapter_number,
                        as: :number,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;"
                        }
              end
            end
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-sort-asc me-2"
                  span "Verse Number"
                end
                f.input :verse_number,
                        as: :number,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;"
                        }
              end
            end
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-sort-asc me-2"
                  span "Unit Number"
                end
                f.input :unit_number,
                        as: :number,
                        class: "materio-form-control",
                        label: false,
                        input_html: {
                          class: "materio-form-control",
                          style: "width: 100%; max-width: 500px;"
                        }
              end
            end
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "Unit Key"
            end
            f.input :unit_key,
                    as: :string,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter unit key (e.g., 'LXX|GEN|1|1' or 'QUR|002|255')..."
                    }
          end

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
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter the text content...",
                      rows: 4
                    }
          end

          # Canon checkboxes in a grid
          div class: "materio-form-group" do
            div class: "materio-form-label mb-3" do
              i class: "ri ri-list-check me-2"
              span "Canon Assignments"
            end
            div class: "row" do
              div class: "col-md-4" do
                div class: "form-check" do
                  f.check_box :canon_catholic, class: "form-check-input"
                  f.label :canon_catholic, "Catholic", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_protestant, class: "form-check-input"
                  f.label :canon_protestant, "Protestant", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_lutheran, class: "form-check-input"
                  f.label :canon_lutheran, "Lutheran", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_anglican, class: "form-check-input"
                  f.label :canon_anglican, "Anglican", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_greek_orthodox, class: "form-check-input"
                  f.label :canon_greek_orthodox, "Greek Orthodox", class: "form-check-label"
                end
              end
              div class: "col-md-4" do
                div class: "form-check" do
                  f.check_box :canon_russian_orthodox, class: "form-check-input"
                  f.label :canon_russian_orthodox, "Russian Orthodox", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_georgian_orthodox, class: "form-check-input"
                  f.label :canon_georgian_orthodox, "Georgian Orthodox", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_western_orthodox, class: "form-check-input"
                  f.label :canon_western_orthodox, "Western Orthodox", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_coptic, class: "form-check-input"
                  f.label :canon_coptic, "Coptic", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_armenian, class: "form-check-input"
                  f.label :canon_armenian, "Armenian", class: "form-check-label"
                end
              end
              div class: "col-md-4" do
                div class: "form-check" do
                  f.check_box :canon_ethiopian, class: "form-check-input"
                  f.label :canon_ethiopian, "Ethiopian", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_syriac, class: "form-check-input"
                  f.label :canon_syriac, "Syriac", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_church_east, class: "form-check-input"
                  f.label :canon_church_east, "Church of the East", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_judaic, class: "form-check-input"
                  f.label :canon_judaic, "Judaic", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_samaritan, class: "form-check-input"
                  f.label :canon_samaritan, "Samaritan", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_lds, class: "form-check-input"
                  f.label :canon_lds, "LDS", class: "form-check-label"
                end
                div class: "form-check" do
                  f.check_box :canon_quran, class: "form-check-input"
                  f.label :canon_quran, "Quran", class: "form-check-label"
                end
              end
            end
          end
        end
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Text Content", type: "submit", class: "btn btn-primary"
            else
              button "Update Text Content", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_text_contents_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Text Content: #{resource.unit_key}", class: "mb-1 fw-bold text-dark"
        p "Source: #{resource.source.name} | Book: #{resource.book.std_name}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Text Content", edit_admin_text_content_path(resource), class: "btn btn-primary px-3 py-2"
        link_to "Back to Text Contents", admin_text_contents_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-file-text-line me-2"
              "Text Content Details"
            end
          end
          div class: "card-body p-4" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-code-line me-2"
                    "Unit Key"
                  end
                  div class: "fw-semibold text-dark" do resource.unit_key end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-book-line me-2"
                    "Source"
                  end
                  div class: "fw-semibold text-dark" do resource.source.name end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-book-open-line me-2"
                    "Book"
                  end
                  div class: "fw-semibold text-dark" do resource.book.std_name end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-list-check me-2"
                    "Unit Type"
                  end
                  div class: "fw-semibold text-dark" do resource.text_unit_type.name end
                end
              end
              div class: "col-12" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-file-text-line me-2"
                    "Content"
                  end
                  div class: "fw-semibold text-dark" do resource.content end
                end
              end
            end
          end
        end
      end
      div class: "col-lg-4" do
        div class: "materio-metric-card materio-metric-card-light" do
          div class: "materio-icon primary" do
            i class: "ri ri-list-check"
          end
          h6 "Canon Assignments", class: "mb-2 fw-semibold"
          div class: "fw-bold text-dark mb-2" do resource.canon_list end
          p "Assigned canons", class: "text-muted small mb-0"
        end
      end
    end
  end
end
