ActiveAdmin.register TextContent do
  permit_params :source_id, :book_id, :text_unit_type_id, :language_id, :parent_unit_id,
                :unit_group, :unit, :content, :unit_key,
                :canon_catholic, :canon_protestant, :canon_lutheran, :canon_anglican,
                :canon_greek_orthodox, :canon_russian_orthodox, :canon_georgian_orthodox,
                :canon_western_orthodox, :canon_coptic, :canon_armenian, :canon_ethiopian,
                :canon_syriac, :canon_church_east, :canon_judaic, :canon_samaritan,
                :canon_lds, :canon_quran
  menu label: "Text Contents", priority: 11
  controller { layout "active_admin_custom" }

  # Add filters
  filter :source, as: :select, collection: -> { Source.ordered.map { |s| [s.display_name, s.id] } }
  filter :book, as: :select, collection: -> { Book.ordered.map { |b| [b.display_name, b.id] } }
  filter :text_unit_type, as: :select, collection: -> { TextUnitType.ordered.map { |t| [t.display_name, t.id] } }
  filter :language, as: :select, collection: -> { Language.ordered.map { |l| [l.display_name, l.id] } }
  filter :unit_group, label: "Chapter/Unit Group"
  filter :unit, label: "Verse/Unit"
  filter :unit_key, label: "Unit Key"
  filter :content, label: "Content"
  
  # Canon filters
  filter :canon_catholic, label: "Catholic Canon"
  filter :canon_protestant, label: "Protestant Canon"
  filter :canon_lutheran, label: "Lutheran Canon"
  filter :canon_anglican, label: "Anglican Canon"
  filter :canon_greek_orthodox, label: "Greek Orthodox Canon"
  filter :canon_russian_orthodox, label: "Russian Orthodox Canon"
  filter :canon_georgian_orthodox, label: "Georgian Orthodox Canon"
  filter :canon_western_orthodox, label: "Western Orthodox Canon"
  filter :canon_coptic, label: "Coptic Canon"
  filter :canon_armenian, label: "Armenian Canon"
  filter :canon_ethiopian, label: "Ethiopian Canon"
  filter :canon_syriac, label: "Syriac Canon"
  filter :canon_church_east, label: "Church of the East Canon"
  filter :canon_judaic, label: "Judaic Canon"
  filter :canon_samaritan, label: "Samaritan Canon"
  filter :canon_lds, label: "LDS Canon"
  filter :canon_quran, label: "Quran Canon"

  # Configure pagination for large datasets
  config.paginate = true
  config.per_page = 50
  config.max_per_page = 1000

  # Add sorting
  config.sort_order = 'unit_key_asc'

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

    # Custom filter region
    div class: "card mb-4" do
      div class: "card-header bg-light" do
        h5 "Quick Filters", class: "mb-0"
      end
      div class: "card-body" do
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Source", class: "form-label"
            select class: "form-select", id: "quick-source-filter" do
              option "All Sources", value: ""
              Source.ordered.each do |source|
                option source.display_name, value: source.id
              end
            end
          end
          div class: "col-md-3" do
            label "Book", class: "form-label"
            select class: "form-select", id: "quick-book-filter" do
              option "All Books", value: ""
              Book.ordered.each do |book|
                option book.display_name, value: book.id
              end
            end
          end
          div class: "col-md-2" do
            label "Chapter/Group", class: "form-label"
            input type: "number", class: "form-control", id: "quick-chapter-filter", placeholder: "e.g., 1"
          end
          div class: "col-md-2" do
            label "Verse/Unit", class: "form-label"
            input type: "number", class: "form-control", id: "quick-verse-filter", placeholder: "e.g., 5"
          end
          div class: "col-md-2" do
            label "Canon", class: "form-label"
            select class: "form-select", id: "quick-canon-filter" do
              option "All Canons", value: ""
              option "Catholic", value: "catholic"
              option "Protestant", value: "protestant"
              option "Orthodox", value: "orthodox"
              option "Quran", value: "quran"
            end
          end
        end
        div class: "row mt-3" do
          div class: "col-12" do
            button "Apply Filters", class: "btn btn-primary me-2", id: "apply-quick-filters"
            button "Clear Filters", class: "btn btn-outline-secondary", id: "clear-quick-filters"
          end
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
              div class: "d-flex flex-wrap gap-1" do
                if text_content.canon_list.present?
                  text_content.canon_list.split(", ").each do |canon|
                    span class: "badge bg-success" do canon end
                  end
                else
                  span class: "badge bg-secondary" do "None" end
                end
              end
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

    # Add JavaScript for quick filters
    script do
      raw "
      document.addEventListener('DOMContentLoaded', function() {
        const applyBtn = document.getElementById('apply-quick-filters');
        const clearBtn = document.getElementById('clear-quick-filters');
        
        if (applyBtn) {
          applyBtn.addEventListener('click', function() {
            const sourceId = document.getElementById('quick-source-filter').value;
            const bookId = document.getElementById('quick-book-filter').value;
            const chapter = document.getElementById('quick-chapter-filter').value;
            const verse = document.getElementById('quick-verse-filter').value;
            const canon = document.getElementById('quick-canon-filter').value;
            
            console.log('Filter values:', { sourceId, bookId, chapter, verse, canon });
            
            let url = window.location.pathname;
            const params = new URLSearchParams();
            
            if (sourceId && sourceId !== '') params.append('q[source_id_eq]', sourceId);
            if (bookId && bookId !== '' && bookId !== 'All Books') params.append('q[book_id_eq]', bookId);
            if (chapter && chapter !== '') params.append('q[unit_group_eq]', chapter);
            if (verse && verse !== '') params.append('q[unit_eq]', verse);
            if (canon && canon !== '' && canon !== 'All Canons') {
              if (canon === 'orthodox') {
                params.append('q[canon_greek_orthodox_true]', '1');
              } else {
                params.append('q[canon_' + canon + '_true]', '1');
              }
            }
            
            console.log('Final URL:', url + (params.toString() ? '?' + params.toString() : ''));
            
            if (params.toString()) {
              url += '?' + params.toString();
            }
            
            window.location.href = url;
          });
        }
        
        if (clearBtn) {
          clearBtn.addEventListener('click', function() {
            window.location.href = window.location.pathname;
          });
        }
        
        // Pre-populate filters from URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const sourceIdParam = urlParams.get('q[source_id_eq]');
        const bookIdParam = urlParams.get('q[book_id_eq]');
        const chapterParam = urlParams.get('q[unit_group_eq]');
        const verseParam = urlParams.get('q[unit_eq]');
        
        if (sourceIdParam) {
          document.getElementById('quick-source-filter').value = sourceIdParam;
        }
        if (bookIdParam) {
          document.getElementById('quick-book-filter').value = bookIdParam;
        }
        if (chapterParam) {
          document.getElementById('quick-chapter-filter').value = chapterParam;
        }
        if (verseParam) {
          document.getElementById('quick-verse-filter').value = verseParam;
        }
      });
      "
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
                div class: "form-control", style: "width: 100%; max-width: 500px; background-color: #f8f9fa; border: 1px solid #dee2e6;" do
                  span id: "text-unit-type-display", class: "text-muted" do
                    "Select a source to see the text unit type"
                  end
                end
                f.hidden_field :text_unit_type_id, id: "text-unit-type-hidden"
              end
            end
            div class: "col-md-6" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-translate me-2"
                  span "Language"
                end
                div class: "form-control", style: "width: 100%; max-width: 500px; background-color: #f8f9fa; border: 1px solid #dee2e6;" do
                  span id: "language-display", class: "text-muted" do
                    "Select a source to see the language"
                  end
                end
                f.hidden_field :language_id, id: "language-hidden"
              end
            end
          end

          div class: "row" do
            div class: "col-md-4" do
              div class: "materio-form-group" do
                div class: "materio-form-label" do
                  i class: "ri ri-sort-asc me-2"
                  span "Unit Group"
                end
                f.input :unit_group,
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
                  span "Unit"
                end
                f.input :unit,
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
            div class: "form-control", style: "width: 100%; max-width: 500px; background-color: #f8f9fa; border: 1px solid #dee2e6;" do
              span id: "unit-key-display", class: "text-muted" do
                "Select source, book, and enter unit details to generate unit key"
              end
            end
            f.hidden_field :unit_key, id: "unit-key-hidden"
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

    # Add JavaScript to handle source selection and unit key generation
    script do
      raw "
      document.addEventListener('DOMContentLoaded', function() {
        const sourceSelect = document.querySelector('select[name=\"text_content[source_id]\"]');
        const bookSelect = document.querySelector('select[name=\"text_content[book_id]\"]');
        const unitGroupInput = document.querySelector('input[name=\"text_content[unit_group]\"]');
        const unitInput = document.querySelector('input[name=\"text_content[unit]\"]');
        
        const textUnitTypeDisplay = document.getElementById('text-unit-type-display');
        const textUnitTypeHidden = document.getElementById('text-unit-type-hidden');
        const languageDisplay = document.getElementById('language-display');
        const languageHidden = document.getElementById('language-hidden');
        const unitKeyDisplay = document.getElementById('unit-key-display');
        const unitKeyHidden = document.getElementById('unit-key-hidden');

        // Function to generate unit key
        function generateUnitKey() {
          const sourceId = sourceSelect ? sourceSelect.value : '';
          const bookId = bookSelect ? bookSelect.value : '';
          const unitGroup = unitGroupInput ? unitGroupInput.value : '';
          const unit = unitInput ? unitInput.value : '';
          
          if (sourceId && bookId) {
            // Get source and book codes from the select options
            const sourceOption = sourceSelect.querySelector('option:checked');
            const bookOption = bookSelect.querySelector('option:checked');
            
            if (sourceOption && bookOption) {
              const sourceCode = sourceOption.textContent.match(/\\(([^)]+)\\)/)?.[1] || '';
              const bookCode = bookOption.textContent.match(/\\(([^)]+)\\)/)?.[1] || '';
              
              let unitKey = sourceCode + '|' + bookCode;
              
              if (unitGroup) {
                unitKey += '|' + unitGroup;
              }
              if (unit) {
                unitKey += '|' + unit;
              }
              
              unitKeyDisplay.textContent = unitKey;
              unitKeyHidden.value = unitKey;
            }
          } else {
            unitKeyDisplay.textContent = 'Select source, book, and enter unit details to generate unit key';
            unitKeyHidden.value = '';
          }
        }

        // Function to handle source selection
        function handleSourceChange() {
          const sourceId = sourceSelect.value;
          if (sourceId) {
            // Fetch source data via AJAX
            fetch('/admin/sources/' + sourceId + '.json')
              .then(response => response.json())
              .then(data => {
                if (data.text_unit_type) {
                  textUnitTypeDisplay.textContent = data.text_unit_type.name + ' (' + data.text_unit_type.code + ')';
                  textUnitTypeHidden.value = data.text_unit_type.id;
                } else {
                  textUnitTypeDisplay.textContent = 'No text unit type assigned to this source';
                  textUnitTypeHidden.value = '';
                }
                
                if (data.language) {
                  languageDisplay.textContent = data.language.name + ' (' + data.language.code + ')';
                  languageHidden.value = data.language.id;
                } else {
                  languageDisplay.textContent = 'No language assigned to this source';
                  languageHidden.value = '';
                }
                
                // Regenerate unit key after source change
                generateUnitKey();
              })
              .catch(error => {
                console.error('Error fetching source data:', error);
                textUnitTypeDisplay.textContent = 'Error loading text unit type';
                languageDisplay.textContent = 'Error loading language';
              });
          } else {
            textUnitTypeDisplay.textContent = 'Select a source to see the text unit type';
            textUnitTypeHidden.value = '';
            languageDisplay.textContent = 'Select a source to see the language';
            languageHidden.value = '';
            generateUnitKey();
          }
        }

        // Add event listeners
        if (sourceSelect) {
          sourceSelect.addEventListener('change', handleSourceChange);
        }
        
        if (bookSelect) {
          bookSelect.addEventListener('change', generateUnitKey);
        }
        
        if (unitGroupInput) {
          unitGroupInput.addEventListener('input', generateUnitKey);
        }
        
        if (unitInput) {
          unitInput.addEventListener('input', generateUnitKey);
        }
        
        // Generate initial unit key if form is being edited
        generateUnitKey();
      });
      "
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
