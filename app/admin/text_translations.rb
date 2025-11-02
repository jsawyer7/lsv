ActiveAdmin.register TextTranslation do
  permit_params :text_content_id, :language_target_id, :ai_translation,
                :ai_explanation, :ai_model_name, :ai_confidence_score, :revision_number, :is_latest,
                :confirmed_at, :confirmed_by, :notes, :summary_and_differences

  menu parent: "Data Tables", label: "Text Translations", priority: 9
  controller { layout "active_admin_custom" }

  filter :text_content_id, label: "Text Content UUID"
  filter :language_target, as: :select, collection: -> { Language.ordered.map { |l| [l.display_name, l.id] } }, label: "Target Language"
  filter :revision_number
  filter :is_latest
  filter :ai_model_name
  filter :ai_confidence_score
  filter :confirmed_at

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Text Translations", class: "mb-2"
          para "Manage AI and word-for-word translations per text content", class: "text-muted"
        end
        div do
          link_to "Add Translation", new_admin_text_translation_path, class: "btn btn-primary"
        end
      end
    end

    table class: "table table-striped table-hover" do
      thead class: "table-dark" do
        tr do
          th "Text Content"
          th "Target Language"
          th "Revision"
          th "Latest"
          th "Model"
          th "Confidence"
          th "Actions", class: "text-end"
        end
      end
      tbody do
        collection.each do |tt|
          tr do
            td do
              span class: "small" do tt.text_content.unit_key end
            end
            td do
              tt.language_target.display_name
            end
            td { tt.revision_number }
            td { status_tag(tt.is_latest ? 'Yes' : 'No', class: tt.is_latest ? 'ok' : 'warning') }
            td { tt.ai_model_name }
            td { tt.ai_confidence_score }
            td class: "text-end" do
              div class: "btn-group" do
                link_to "View", admin_text_translation_path(tt), class: "btn btn-sm btn-outline-primary"
                link_to "Edit", edit_admin_text_translation_path(tt), class: "btn btn-sm btn-outline-secondary"
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
                "Create Text Translation"
              else
                "Edit Text Translation"
              end
            end
            p class: "mb-0 opacity-75" do
              if f.object.new_record?
                "Add new translation for a text content"
              else
                "Update translation information"
              end
            end
          end
          link_to "Back to Translations", admin_text_translations_path, class: "btn btn-light"
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
                    i class: "ri ri-hashtag me-2"
                    span "Text Content"
                  end
                  f.input :text_content_id,
                          as: :select,
                          collection: TextContent.ordered.limit(1000).map { |tc| ["#{tc.unit_key} - #{tc.source.name} - #{tc.book.std_name}", tc.id] },
                          label: false,
                          input_html: {
                            class: "materio-form-control",
                            style: "width: 100%; max-width: 500px;",
                            id: "text-content-select"
                          },
                          prompt: "Select a Text Content..."
                  div class: "small text-muted mt-2", id: "text-content-unit-display" do
                    if f.object.text_content
                      "Unit Key: #{f.object.text_content.unit_key}"
                    else
                      "Select a text content above"
                    end
                  end
                end
              end
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-translate me-2"
                  span "Target Language"
                end
                f.input :language_target_id, as: :select, collection: Language.ordered.map { |l| [l.display_name, l.id] }, label: false, input_html: { style: "width: 100%; max-width: 500px;" }
              end
            end
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-robot-line me-2"
              span "AI's LSV translation"
            end
            f.input :ai_translation, as: :text, label: false, input_html: { rows: 3, style: "width: 100%; max-width: 800px;" }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-chat-1-line me-2"
              span "AI assessment of the Writer's intended meaning"
            end
            f.input :ai_explanation, as: :text, label: false, input_html: { rows: 4, style: "width: 100%; max-width: 800px;" }
          end

          div class: "row" do
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-cpu-line me-2"
                  span "AI Model Name"
                end
                f.input :ai_model_name, as: :string, label: false, input_html: { style: "width: 100%; max-width: 500px;" }
              end
            end
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-bar-chart-2-line me-2"
                  span "AI Confidence (0–1)"
                end
                f.input :ai_confidence_score, as: :number, label: false, input_html: { step: 0.001, min: 0, max: 1, style: "width: 100%; max-width: 300px;" }
              end
            end
            div class: "col-md-2" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-hashtag me-2"
                  span "Revision #"
                end
                f.input :revision_number, as: :number, label: false, input_html: { min: 1, style: "width: 100%; max-width: 200px;" }
              end
            end
            div class: "col-md-2" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-check-double-line me-2"
                  span "Latest?"
                end
                f.input :is_latest, as: :boolean, label: false
              end
            end
          end

          div class: "row" do
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-calendar-line me-2"
                  span "Confirmed at"
                end
                f.input :confirmed_at, as: :datetime_picker, label: false
              end
            end
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-user-2-line me-2"
                  span "Confirmed by"
                end
                f.input :confirmed_by, as: :string, label: false
              end
            end
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-text-line me-2"
              span "Notes"
            end
            f.input :notes, as: :text, label: false, input_html: { rows: 3, style: "width: 100%; max-width: 800px;" }
          end

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-list-3-line me-2"
              span "Summary and differences from main theologies"
            end
            f.input :summary_and_differences, as: :text, label: false, input_html: { rows: 5, style: "width: 100%; max-width: 800px;", placeholder: "Enter summary and differences from main theologies..." }
          end
        end
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              button "Create Translation", type: "submit", class: "btn btn-primary"
            else
              button "Update Translation", type: "submit", class: "btn btn-primary"
            end
            link_to "Cancel", admin_text_translations_path, class: "btn btn-outline-secondary"
          end
        end
      end
    end

    # JavaScript to update unit key display when text content is selected
    script do
      raw "
      document.addEventListener('DOMContentLoaded', function() {
        const textContentSelect = document.getElementById('text-content-select');
        const unitDisplay = document.getElementById('text-content-unit-display');
        
        if (textContentSelect && unitDisplay) {
          textContentSelect.addEventListener('change', function() {
            const selectedOption = this.options[this.selectedIndex];
            if (selectedOption && selectedOption.value) {
              // Extract unit key from the option text (format: 'unit_key - source - book')
              const optionText = selectedOption.text;
              const parts = optionText.split(' - ');
              if (parts.length > 0) {
                unitDisplay.textContent = 'Unit Key: ' + parts[0];
              } else {
                unitDisplay.textContent = 'Unit Key: ' + selectedOption.value;
              }
            } else {
              unitDisplay.textContent = 'Select a text content above';
            }
          });
          
          // Update on page load if already selected
          if (textContentSelect.value) {
            textContentSelect.dispatchEvent(new Event('change'));
          }
        }
      });
      "
    end
  end

  show do
    attributes_table do
      row(:text_content) { |tt| tt.text_content.unit_key }
      row(:language_target) { |tt| tt.language_target.display_name }
      row :revision_number
      row :is_latest
      row :ai_model_name
      row :ai_confidence_score
      row :word_for_word_translation
      row "AI's LSV translation" do |tt| tt.ai_translation end
      row "AI assessment of the Writer's intended meaning" do |tt| tt.ai_explanation end
      row :confirmed_at
      row :confirmed_by
      row :notes
      row "Summary and differences from main theologies" do |tt| tt.summary_and_differences end
      row :created_at
      row :updated_at
    end
  end
end


