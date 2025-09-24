ActiveAdmin.register TextUnit do
  permit_params :unit_id, :tradition, :work_code, :division_code, :chapter, :verse, :subref

  # Custom page title
  menu label: "Text Units", priority: 10

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Text Units Management", class: "mb-2"
      para "Manage text units and their configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Tradition", class: "form-label"
            input type: "text", name: "q[tradition_cont]", placeholder: "Search tradition...", class: "form-control", value: params.dig(:q, :tradition_cont)
          end
          div class: "col-md-3" do
            label "Work Code", class: "form-label"
            input type: "text", name: "q[work_code_cont]", placeholder: "Search work code...", class: "form-control", value: params.dig(:q, :work_code_cont)
          end
          div class: "col-md-3" do
            label "Division Code", class: "form-label"
            input type: "text", name: "q[division_code_cont]", placeholder: "Search division...", class: "form-control", value: params.dig(:q, :division_code_cont)
          end
          div class: "col-md-3" do
            label "Chapter", class: "form-label"
            input type: "number", name: "q[chapter_eq]", placeholder: "Chapter number...", class: "form-control", value: params.dig(:q, :chapter_eq)
          end
        end
        div class: "row g-3 mt-2" do
          div class: "col-md-3" do
            label "Verse", class: "form-label"
            input type: "number", name: "q[verse_eq]", placeholder: "Verse number...", class: "form-control", value: params.dig(:q, :verse_eq)
          end
          div class: "col-md-3" do
            label "Subref", class: "form-label"
            input type: "text", name: "q[subref_cont]", placeholder: "Search subref...", class: "form-control", value: params.dig(:q, :subref_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterTextUnits()" do
            "Filter"
          end
          a href: admin_text_units_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterTextUnits() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_text_units_path}';

          var tradition = document.querySelector('input[name=\"q[tradition_cont]\"]').value;
          var workCode = document.querySelector('input[name=\"q[work_code_cont]\"]').value;
          var divisionCode = document.querySelector('input[name=\"q[division_code_cont]\"]').value;
          var chapter = document.querySelector('input[name=\"q[chapter_eq]\"]').value;
          var verse = document.querySelector('input[name=\"q[verse_eq]\"]').value;
          var subref = document.querySelector('input[name=\"q[subref_cont]\"]').value;

          if (tradition) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[tradition_cont]';
            input.value = tradition;
            form.appendChild(input);
          }

          if (workCode) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[work_code_cont]';
            input.value = workCode;
            form.appendChild(input);
          }

          if (divisionCode) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[division_code_cont]';
            input.value = divisionCode;
            form.appendChild(input);
          }

          if (chapter) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[chapter_eq]';
            input.value = chapter;
            form.appendChild(input);
          }

          if (verse) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[verse_eq]';
            input.value = verse;
            form.appendChild(input);
          }

          if (subref) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[subref_cont]';
            input.value = subref;
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
            th "UNIT ID", class: "fw-semibold"
            th "TRADITION", class: "fw-semibold"
            th "WORK CODE", class: "fw-semibold"
            th "DIVISION CODE", class: "fw-semibold"
            th "CHAPTER", class: "fw-semibold"
            th "VERSE", class: "fw-semibold"
            th "SUBREF", class: "fw-semibold"
            th "CANON MAPS", class: "fw-semibold"
            th "TEXT PAYLOADS", class: "fw-semibold"
            th "CREATED", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          text_units.each do |text_unit|
            tr do
              td do
                link_to text_unit.unit_id, admin_text_unit_path(text_unit), class: "text-decoration-none"
              end
              td text_unit.tradition
              td text_unit.work_code
              td text_unit.division_code
              td text_unit.chapter
              td text_unit.verse
              td text_unit.subref || "N/A"
              td do
                span class: "badge bg-info" do text_unit.canon_maps.count end
              end
              td do
                span class: "badge bg-success" do text_unit.text_payloads.count end
              end
              td text_unit.created_at.strftime("%b %d, %Y")
              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_text_unit_path(text_unit)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_text_unit_path(text_unit)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_text_unit_path(text_unit)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end

    div class: "d-flex justify-content-between align-items-center mt-4" do
      div class: "text-muted" do
        "Showing #{text_units.count} of #{TextUnit.count} text units"
      end
      div do
        link_to "Create New Text Unit", new_admin_text_unit_path, class: "btn btn-primary"
      end
    end
  end

  show do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Text Unit Details", class: "mb-2 text-primary"
          para "View detailed information about this text unit", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Text Unit", edit_admin_text_unit_path(text_unit), class: "btn btn-primary"
          link_to "Back to Text Units", admin_text_units_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Text Unit Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-file-text-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do text_unit.unit_id end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do text_unit.tradition end
            end
            para class: "text-muted mb-0" do "#{text_unit.work_code} - #{text_unit.division_code}" end
          end
        end
      end

      # Text Unit Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Text Unit Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-hashtag text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Unit ID" end
                    div class: "fw-semibold" do text_unit.unit_id end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-book-open-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Tradition" end
                    div class: "fw-semibold" do text_unit.tradition end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-file-code-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Work Code" end
                    div class: "fw-semibold" do text_unit.work_code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-folder-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Division Code" end
                    div class: "fw-semibold" do text_unit.division_code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do text_unit.chapter end
                  div class: "materio-metric-label" do "Chapter" end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do text_unit.verse end
                  div class: "materio-metric-label" do "Verse" end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-subtract-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Subref" end
                    div class: "fw-semibold" do text_unit.subref || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-calendar-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Created" end
                    div class: "fw-semibold" do text_unit.created_at.strftime("%B %d, %Y") end
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
          h1 (f.object.persisted? ? "Edit Text Unit" : "Create Text Unit"), class: "mb-2 text-primary"
          para (f.object.persisted? ? "Update text unit information and settings" : "Create a new text unit"), class: "text-muted mb-0"
        end
        div do
          link_to "Back to Text Units", admin_text_units_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: (f.object.persisted? ? "ri ri-edit-line me-2" : "ri ri-add-line me-2")
          (f.object.persisted? ? "Text Unit Information" : "New Text Unit Information")
        end
      end
      div class: "card-body p-4" do
        f.inputs do
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
                      placeholder: "Enter unique unit ID"
                    }
          end

          # Tradition Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-book-open-line me-2"
              span "Tradition"
            end
            f.input :tradition,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter tradition (e.g., quran, bible)"
                    }
          end

          # Work Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-file-code-line me-2"
              span "Work Code"
            end
            f.input :work_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter work code"
                    }
          end

          # Division Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-folder-line me-2"
              span "Division Code"
            end
            f.input :division_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter division code"
                    }
          end

          # Chapter Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-numbers me-2"
              span "Chapter"
            end
            f.input :chapter,
                    as: :number,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter chapter number",
                      min: 1
                    }
          end

          # Verse Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-list-check me-2"
              span "Verse"
            end
            f.input :verse,
                    as: :number,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter verse number",
                      min: 1
                    }
          end

          # Subref Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-subtract-line me-2"
              span "Subref (Optional)"
            end
            f.input :subref,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter subref (optional)"
                    }
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: (f.object.persisted? ? "Update Text Unit" : "Create Text Unit"),
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
  filter :tradition
  filter :work_code
  filter :division_code
  filter :chapter
  filter :verse
  filter :subref
  filter :created_at
end
