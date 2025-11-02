ActiveAdmin.register TextContent do
  permit_params :source_id, :book_id, :text_unit_type_id, :language_id, :parent_unit_id,
                :unit_group, :unit, :content, :unit_key, :word_for_word_translation, :lsv_literal_reconstruction,
                :canon_catholic, :canon_protestant, :canon_lutheran, :canon_anglican,
                :canon_greek_orthodox, :canon_russian_orthodox, :canon_georgian_orthodox,
                :canon_western_orthodox, :canon_coptic, :canon_armenian, :canon_ethiopian,
                :canon_syriac, :canon_church_east, :canon_judaic, :canon_samaritan,
                :canon_lds, :canon_quran
  menu parent: "Data Tables", label: "Text Contents", priority: 8
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
          # Source
          div class: "col-md-3" do
            label "Source", class: "form-label"
            select class: "form-select", id: "quick-source-filter" do
              option "All Sources", value: ""
              Source.ordered.each do |source|
                option source.display_name, value: source.id
              end
            end
          end
          # Canon
          div class: "col-md-2" do
            label "Canon", class: "form-label"
            select class: "form-select", id: "quick-canon-filter", 'data-keys': Canon.ordered.map { |c| c.code.to_s.parameterize.underscore }.to_json do
              option "All Canons", value: ""
              Canon.ordered.each do |canon|
                option canon.name, value: canon.code.to_s.parameterize.underscore
              end
            end
          end
          # Book
          div class: "col-md-3" do
            label "Book", class: "form-label"
            select class: "form-select", id: "quick-book-filter" do
              option "All Books", value: ""
              Book.ordered.each do |book|
                option book.display_name, value: book.id
              end
            end
          end
          # Unit Group
          div class: "col-md-2" do
            label "Unit Group (e.g., Chapter)", class: "form-label"
            input type: "number", class: "form-control", id: "quick-chapter-filter", placeholder: "e.g., 1"
          end
          # Unit
          div class: "col-md-2" do
            label "Unit (e.g., Verse)", class: "form-label"
            input type: "number", class: "form-control", id: "quick-verse-filter", placeholder: "e.g., 5"
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
              params.append('q[canon_' + canon + '_true]', '1');
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
        // Preselect canon if present in URL (keys provided by data-keys on the select)
        const canonSelect = document.getElementById('quick-canon-filter');
        const canonKeys = canonSelect ? JSON.parse(canonSelect.dataset.keys || '[]') : [];
        for (const key of canonKeys) {
          if (urlParams.get(`q[canon_${key}_true]`) === '1') {
            if (canonSelect) canonSelect.value = key;
            break;
          }
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
                  span " (e.g., Chapter)", class: "text-muted ms-2 small"
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
                  span " (e.g., Verse)", class: "text-muted ms-2 small"
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

          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-text-wrap me-2"
              span "LSV Literal Reconstruction"
            end
            f.input :lsv_literal_reconstruction,
                    as: :text,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      style: "width: 100%; max-width: 500px;",
                      placeholder: "Enter LSV literal reconstruction...",
                      rows: 4
                    }
          end

          # Word-for-Word Translation Table
          div class: "materio-card mt-4" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-translate-2 me-2"
                "Word-for-Word Translation"
              end
            end
            div class: "card-body" do
              div id: "word-for-word-table-container" do
                if f.object.word_for_word_array.present?
                  table class: "table table-striped" do
                    thead class: "table-dark" do
                      tr do
                        th "#{f.object.language.name} word"
                        th "Literal meaning"
                        th "Confidence (1–100)"
                        th "Notes"
                      end
                    end
                    tbody do
                      f.object.word_for_word_array.each do |word|
                        tr do
                          td class: "fw-semibold" do word['word'] || word[:word] || '' end
                          td do word['literal_meaning'] || word[:literal_meaning] || '' end
                          td do word['confidence'] || word[:confidence] || '' end
                          td class: "small text-muted" do word['notes'] || word[:notes] || '' end
                        end
                      end
                    end
                  end
                else
                  p class: "text-muted" do "No word-for-word translation available. This will be populated by AI during import." end
                end
              end
              div class: "mt-3" do
                f.input :word_for_word_translation,
                        as: :text,
                        label: "Word-for-Word JSON (for editing)",
                        input_html: {
                          rows: 5,
                          class: "form-control font-monospace small",
                          placeholder: '[{"word": "In", "literal_meaning": "in / within", "confidence": 100, "notes": "Fixed Latin preposition—no ambiguity."}, ...]',
                          style: "width: 100%; max-width: 800px;"
                        }
              end
            end
          end

          # Canon checkboxes in a grid - dynamically show only canons that exist in database
          div class: "materio-form-group" do
            div class: "materio-form-label mb-3" do
              i class: "ri ri-list-check me-2"
              span "Canon Assignments"
            end
            div class: "row" do
              # Get all canons from database and map to TextContent fields
              existing_canons = Canon.ordered.all.select do |canon|
                TextContent::CODE_TO_CANON_FIELD.key?(canon.code)
              end
              
              # Split into columns (approximately equal distribution)
              cols = 3
              per_col = (existing_canons.length.to_f / cols).ceil
              
              cols.times do |col_idx|
                div class: "col-md-4" do
                  start_idx = col_idx * per_col
                  end_idx = start_idx + per_col - 1
                  existing_canons[start_idx..end_idx].each do |canon|
                    field = TextContent::CODE_TO_CANON_FIELD[canon.code]
                    next unless field # Skip if no mapping exists
                    
                    div class: "form-check" do
                      f.check_box field, class: "form-check-input"
                      f.label field, canon.name, class: "form-check-label"
                    end
                  end
                end
              end
            end
          end
          # Preview section
          div class: "materio-card mt-4" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-eye-line me-2"
                "Preview"
              end
            end
            div class: "card-body" do
              div id: "tc-preview-path", class: "mb-2 fw-semibold" do
                ""
              end
              div id: "tc-preview-content", class: "p-3 rounded border bg-light" do
                ""
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

    # Add JavaScript to handle source selection, unit key generation, normalization, and preview
    script do
      raw "
      document.addEventListener('DOMContentLoaded', function() {
        const sourceSelect = document.querySelector('select[name=\"text_content[source_id]\"]');
        const bookSelect = document.querySelector('select[name=\"text_content[book_id]\"]');
        const unitGroupInput = document.querySelector('input[name=\"text_content[unit_group]\"]');
        const unitInput = document.querySelector('input[name=\"text_content[unit]\"]');
        const contentInput = document.querySelector('textarea[name=\"text_content[content]\"]');
        
        const textUnitTypeDisplay = document.getElementById('text-unit-type-display');
        const textUnitTypeHidden = document.getElementById('text-unit-type-hidden');
        const languageDisplay = document.getElementById('language-display');
        const languageHidden = document.getElementById('language-hidden');
        const unitKeyDisplay = document.getElementById('unit-key-display');
        const unitKeyHidden = document.getElementById('unit-key-hidden');
        const previewPath = document.getElementById('tc-preview-path');
        const previewContent = document.getElementById('tc-preview-content');

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

        function normalizeGreekPunctuation(text) {
          if (!text) return '';
          let t = text.trim();
          if (t.normalize) t = t.normalize('NFC');
          t = t.replace(/;/g, '\\u037E');
          t = t.replace(/\\u00B7/g, '\\u0387');
          t = t.replace(/\\s+/g, ' ');
          return t;
        }

        function updatePreview() {
          const sourceText = sourceSelect ? (sourceSelect.options[sourceSelect.selectedIndex]?.text || '') : '';
          const bookText = bookSelect ? (bookSelect.options[bookSelect.selectedIndex]?.text || '') : '';
          const langText = languageDisplay ? languageDisplay.textContent : '';
          const ug = unitGroupInput?.value || '';
          const u = unitInput?.value || '';
          const content = normalizeGreekPunctuation(contentInput?.value || '');

          const parts = [];
          if (sourceText) parts.push(sourceText.split('(')[0].trim());
          if (langText && langText.indexOf('Select a source') === -1) parts.push(langText.split('(')[0].trim());
          if (bookText) parts.push(bookText.split('(')[0].trim());
          if (ug) parts.push(ug + (u ? ':' + u : ''));
          if (previewPath) previewPath.textContent = parts.join(' \u2192 ');
          if (previewContent) previewContent.textContent = content;
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
                updatePreview();
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
            updatePreview();
          }
        }

        // Add event listeners
        if (sourceSelect) {
          sourceSelect.addEventListener('change', handleSourceChange);
        }
        
        if (bookSelect) {
          bookSelect.addEventListener('change', function(){ generateUnitKey(); updatePreview(); });
        }
        
        if (unitGroupInput) {
          unitGroupInput.addEventListener('input', function(){ generateUnitKey(); updatePreview(); });
        }
        
        if (unitInput) {
          unitInput.addEventListener('input', function(){ generateUnitKey(); updatePreview(); });
        }

        if (contentInput) {
          contentInput.addEventListener('input', function(){ updatePreview(); });
        }
        
        // On edit, if a source is already selected, hydrate dependent fields
        if (sourceSelect && sourceSelect.value) {
          handleSourceChange();
        }
        // Generate initial unit key if form is being edited
        generateUnitKey();
        updatePreview();

        // Normalize on submit
        const form = document.querySelector('form');
        if (form && contentInput) {
          form.addEventListener('submit', function(){
            contentInput.value = normalizeGreekPunctuation(contentInput.value);
          });
        }

        // Word-for-word translation table update
        const wordForWordInput = document.querySelector('textarea[name=\"text_content[word_for_word_translation]\"]');
        const wordForWordContainer = document.getElementById('word-for-word-table-container');
        
        function updateWordForWordTable() {
          if (!wordForWordInput || !wordForWordContainer) return;
          
          const jsonText = wordForWordInput.value.trim();
          if (!jsonText) {
            wordForWordContainer.innerHTML = '<p class=\"text-muted\">No word-for-word translation available. Enter JSON array in the field below.</p>';
            return;
          }
          
          try {
            const words = JSON.parse(jsonText);
            if (!Array.isArray(words)) {
              wordForWordContainer.innerHTML = '<p class=\"text-danger\">JSON must be an array of word objects.</p>';
              return;
            }
            
            if (words.length === 0) {
              wordForWordContainer.innerHTML = '<p class=\"text-muted\">Word array is empty.</p>';
              return;
            }
            
            const languageName = languageDisplay ? languageDisplay.textContent.split('(')[0].trim() : 'Source';
            let tableHTML = '<table class=\"table table-striped\"><thead class=\"table-dark\"><tr><th>' + languageName + ' word</th><th>Literal meaning</th><th>Confidence (1–100)</th><th>Notes</th></tr></thead><tbody>';
            
            words.forEach(function(word) {
              tableHTML += '<tr><td class=\"fw-semibold\">' + (word.word || '') + '</td>';
              tableHTML += '<td>' + (word.literal_meaning || '') + '</td>';
              tableHTML += '<td>' + (word.confidence || '') + '</td>';
              tableHTML += '<td class=\"small text-muted\">' + (word.notes || '') + '</td></tr>';
            });
            
            tableHTML += '</tbody></table>';
            wordForWordContainer.innerHTML = tableHTML;
          } catch (e) {
            wordForWordContainer.innerHTML = '<p class=\"text-danger\">Invalid JSON: ' + e.message + '</p>';
          }
        }
        
        if (wordForWordInput) {
          wordForWordInput.addEventListener('input', updateWordForWordTable);
          updateWordForWordTable();
        }
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
              div class: "col-12" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-text-wrap me-2"
                    "LSV Literal Reconstruction"
                  end
                  div class: "fw-semibold text-dark" do
                    if resource.lsv_literal_reconstruction.present?
                      resource.lsv_literal_reconstruction
                    else
                      span class: "text-muted" do "No LSV literal reconstruction provided" end
                    end
                  end
                end
              end
            end
          end
        end

        # Word-for-Word Translation Table
        div class: "materio-card mt-4" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-translate-2 me-2"
              "Word-for-Word Translation"
            end
          end
          div class: "card-body" do
            if resource.word_for_word_array.present?
              table class: "table table-striped" do
                thead class: "table-dark" do
                  tr do
                    th "#{resource.language.name} word"
                    th "Literal meaning"
                    th "Confidence (1–100)"
                    th "Notes"
                  end
                end
                tbody do
                  resource.word_for_word_array.each do |word|
                    tr do
                      td class: "fw-semibold" do word['word'] || word[:word] || '' end
                      td do word['literal_meaning'] || word[:literal_meaning] || '' end
                      td do word['confidence'] || word[:confidence] || '' end
                      td class: "small text-muted" do word['notes'] || word[:notes] || '' end
                    end
                  end
                end
              end
            else
              p class: "text-muted" do "No word-for-word translation available." end
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
