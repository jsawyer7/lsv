ActiveAdmin.register NumberingLabel do
  permit_params :numbering_system_id, :system_code, :label, :locale, :applies_to, :description

  # Custom page title
  menu label: "Numbering Labels", priority: 8

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Numbering Labels Management", class: "mb-2"
      para "Manage numbering labels and their configurations", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "System Code", class: "form-label"
            input type: "text", name: "q[system_code_cont]", placeholder: "Search system code...", class: "form-control", value: params.dig(:q, :system_code_cont)
          end
          div class: "col-md-3" do
            label "Label", class: "form-label"
            input type: "text", name: "q[label_cont]", placeholder: "Search label...", class: "form-control", value: params.dig(:q, :label_cont)
          end
          div class: "col-md-3" do
            label "Locale", class: "form-label"
            input type: "text", name: "q[locale_cont]", placeholder: "Search locale...", class: "form-control", value: params.dig(:q, :locale_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterNumberingLabels()" do
            "Filter"
          end
          a href: admin_numbering_labels_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterNumberingLabels() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_numbering_labels_path}';

          var systemCode = document.querySelector('input[name=\"q[system_code_cont]\"]').value;
          var label = document.querySelector('input[name=\"q[label_cont]\"]').value;
          var locale = document.querySelector('input[name=\"q[locale_cont]\"]').value;

          if (systemCode) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[system_code_cont]';
            input.value = systemCode;
            form.appendChild(input);
          }

          if (label) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[label_cont]';
            input.value = label;
            form.appendChild(input);
          }

          if (locale) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[locale_cont]';
            input.value = locale;
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
            th "SYSTEM CODE", class: "fw-semibold"
            th "LABEL", class: "fw-semibold"
            th "LOCALE", class: "fw-semibold"
            th "APPLIES TO", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          numbering_labels.each do |numbering_label|
            tr do
              # SYSTEM column
              td do
                span class: "text-body fw-semibold" do
                  numbering_label.numbering_system.name
                end
              end

              # SYSTEM CODE column
              td do
                span class: "badge bg-primary" do
                  numbering_label.system_code
                end
              end

              # LABEL column
              td do
                div class: "fw-semibold" do
                  numbering_label.label
                end
              end

              # LOCALE column
              td do
                span class: "text-body" do
                  numbering_label.locale || "N/A"
                end
              end

              # APPLIES TO column
              td do
                span class: "text-body" do
                  numbering_label.applies_to || "N/A"
                end
              end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_numbering_label_path(numbering_label)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_numbering_label_path(numbering_label)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_numbering_label_path(numbering_label)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :numbering_system
  filter :system_code
  filter :label
  filter :locale
  filter :applies_to
  filter :created_at

  form do |f|

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Edit Numbering Label", class: "mb-2 text-primary"
          para "Update numbering label information and settings", class: "text-muted mb-0"
        end
        div do
          link_to "Back to Numbering Labels", admin_numbering_labels_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-edit-line me-2"
          "Numbering Label Information"
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

          # System Code Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-code-line me-2"
              span "System Code"
            end
            f.input :system_code,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter system code..."
                    }
          end

          # Label Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-price-tag-3-line me-2"
              span "Label"
            end
            f.input :label,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter label..."
                    }
          end

          # Locale Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Locale"
            end
            f.input :locale,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter locale (e.g., en, es, fr)..."
                    }
          end

          # Applies To Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-focus-3-line me-2"
              span "Applies To"
            end
            f.input :applies_to,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter applies to..."
                    }
          end

          # Description Input
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
                      placeholder: "Enter description...",
                      rows: 4
                    }
          end
        end

        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: "Update Numbering Label",
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
          h1 "Numbering Label Details", class: "mb-2 text-primary"
          para "View detailed information about this numbering label", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Numbering Label", edit_admin_numbering_label_path(numbering_label), class: "btn btn-primary"
          link_to "Back to Numbering Labels", admin_numbering_labels_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Label Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-price-tag-3-line text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do numbering_label.label end
            div class: "d-flex justify-content-center gap-2 mb-3" do
              span class: "badge bg-primary fs-6" do numbering_label.system_code end
              if numbering_label.locale.present?
                span class: "badge bg-info fs-6" do numbering_label.locale end
              end
            end
            if numbering_label.description.present?
              p class: "text-muted mb-0" do numbering_label.description end
            end
          end
        end
      end

      # Label Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Label Information"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-list-numbers text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Numbering System" end
                    div class: "fw-semibold" do numbering_label.numbering_system.name end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-code-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "System Code" end
                    div class: "fw-semibold" do numbering_label.system_code end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-price-tag-3-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Label" end
                    div class: "fw-semibold" do numbering_label.label end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-global-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Locale" end
                    div class: "fw-semibold" do numbering_label.locale || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-focus-3-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Applies To" end
                    div class: "fw-semibold" do numbering_label.applies_to || "N/A" end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do numbering_label.id end
                  div class: "materio-metric-label" do "Label ID" end
                end
              end
              if numbering_label.description.present?
                div class: "col-12" do
                  div class: "p-3 bg-light rounded" do
                    div class: "text-muted small mb-2" do
                      i class: "ri ri-file-text-line me-1"
                      "Description"
                    end
                    div class: "fw-semibold" do numbering_label.description end
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
