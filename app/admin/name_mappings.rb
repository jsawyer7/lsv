ActiveAdmin.register NameMapping do
  permit_params :internal_id, :jewish, :christian, :muslim, :actual, :ethiopian

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Name Mappings Management", class: "mb-2"
          para "Manage religious name translations across different traditions", class: "text-muted mb-0"
        end
        div do
          link_to new_admin_name_mapping_path, class: "btn btn-primary" do
            raw("<i class='ri ri-add-line me-2'></i>Create Name Mapping")
          end
        end
      end
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Internal ID", class: "form-label"
            input type: "text", name: "q[internal_id_cont]", placeholder: "Search internal ID...", class: "form-control", value: params.dig(:q, :internal_id_cont)
          end
          div class: "col-md-3" do
            label "Jewish Name", class: "form-label"
            input type: "text", name: "q[jewish_cont]", placeholder: "Search Jewish name...", class: "form-control", value: params.dig(:q, :jewish_cont)
          end
          div class: "col-md-3" do
            label "Christian Name", class: "form-label"
            input type: "text", name: "q[christian_cont]", placeholder: "Search Christian name...", class: "form-control", value: params.dig(:q, :christian_cont)
          end
          div class: "col-md-3" do
            label "Muslim Name", class: "form-label"
            input type: "text", name: "q[muslim_cont]", placeholder: "Search Muslim name...", class: "form-control", value: params.dig(:q, :muslim_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterMappings()" do
            "Filter"
          end
          a href: admin_name_mappings_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterMappings() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_name_mappings_path}';

          var internalId = document.querySelector('input[name=\"q[internal_id_cont]\"]').value;
          var jewish = document.querySelector('input[name=\"q[jewish_cont]\"]').value;
          var christian = document.querySelector('input[name=\"q[christian_cont]\"]').value;
          var muslim = document.querySelector('input[name=\"q[muslim_cont]\"]').value;

          if (internalId) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[internal_id_cont]';
            input.value = internalId;
            form.appendChild(input);
          }

          if (jewish) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[jewish_cont]';
            input.value = jewish;
            form.appendChild(input);
          }

          if (christian) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[christian_cont]';
            input.value = christian;
            form.appendChild(input);
          }

          if (muslim) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[muslim_cont]';
            input.value = muslim;
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
            th "INTERNAL ID", class: "fw-semibold"
            th "JEWISH", class: "fw-semibold"
            th "CHRISTIAN", class: "fw-semibold"
            th "MUSLIM", class: "fw-semibold"
            th "ACTUAL", class: "fw-semibold"
            th "ETHIOPIAN", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          name_mappings.each do |mapping|
            tr do
              # INTERNAL ID column
              td do
                span class: "text-body fw-semibold" do
                  mapping.internal_id
                end
              end

              # JEWISH column
              td do
                div class: "fw-semibold" do
                  mapping.jewish
                end
              end

              # CHRISTIAN column
              td do
                span class: "text-body" do
                  mapping.christian
                end
              end

              # MUSLIM column
              td do
                span class: "text-body" do
                  mapping.muslim
                end
              end

              # ACTUAL column
              td do
                span class: "text-body" do
                  mapping.actual
                end
              end

              # ETHIOPIAN column
              td do
                span class: "text-body" do
                  mapping.ethiopian
                end
              end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_name_mapping_path(mapping)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_name_mapping_path(mapping)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_name_mapping_path(mapping)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :internal_id
  filter :jewish
  filter :christian
  filter :muslim
  filter :actual
  filter :ethiopian
  filter :created_at

  form do |f|
    # Custom CSS for Materio UI
    style do
      raw("
        .materio-form-group {
          margin-bottom: 2rem;
        }
        .materio-form-label {
          font-weight: 600;
          color: #697a8d;
          margin-bottom: 0.75rem;
          font-size: 0.875rem;
          display: flex;
          align-items: center;
        }
        .materio-form-control {
          border: 1px solid #e7eaf3;
          border-radius: 0.5rem;
          padding: 0.75rem 1rem;
          font-size: 0.875rem;
          transition: all 0.3s ease;
          background-color: #fff;
        }
        .materio-form-control:focus {
          border-color: #696cff;
          box-shadow: 0 0 0 0.2rem rgba(105, 108, 255, 0.25);
          outline: none;
        }
        .materio-btn-primary {
          background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
          border: none;
          border-radius: 0.5rem;
          color: white;
          font-weight: 600;
          font-size: 0.875rem;
          padding: 0.75rem 2rem;
          transition: all 0.3s ease;
          box-shadow: 0 0.125rem 0.25rem rgba(105, 108, 255, 0.3);
        }
        .materio-btn-primary:hover {
          background: linear-gradient(135deg, #5a5fcf 0%, #4a4fb8 100%);
          transform: translateY(-1px);
          box-shadow: 0 0.25rem 0.5rem rgba(105, 108, 255, 0.4);
          color: white;
        }
        .materio-btn-secondary {
          background: white;
          border: 1px solid #e7eaf3;
          border-radius: 0.5rem;
          color: #697a8d;
          font-weight: 600;
          font-size: 0.875rem;
          padding: 0.75rem 2rem;
          transition: all 0.3s ease;
        }
        .materio-btn-secondary:hover {
          background: #f8f9fa;
          border-color: #d9dee3;
          color: #2b2c40;
          transform: translateY(-1px);
          box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.1);
        }
      ")
    end

    # Dynamic header based on action
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          if f.object.new_record?
            h1 "Create Name Mapping", class: "mb-2 text-primary"
            para "Add new religious name translations across different traditions", class: "text-muted mb-0"
          else
            h1 "Edit Name Mapping", class: "mb-2 text-primary"
            para "Update religious name translations across different traditions", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Name Mappings", admin_name_mappings_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-translate me-2"
          "Name Mapping Information"
        end
      end
      div class: "card-body p-5" do
        f.inputs do
          # Internal ID Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-fingerprint-line me-2"
              span "Internal ID"
            end
            f.input :internal_id,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter internal ID (e.g., person_abraham)..."
                    }
          end

          # Jewish Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-star-line me-2"
              span "Jewish Name"
            end
            f.input :jewish,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter Jewish name (e.g., Avraham)..."
                    }
          end

          # Christian Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-cross-line me-2"
              span "Christian Name"
            end
            f.input :christian,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter Christian name (e.g., Abraham)..."
                    }
          end

          # Muslim Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-moon-line me-2"
              span "Muslim Name"
            end
            f.input :muslim,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter Muslim name (e.g., Ibrahim)..."
                    }
          end

          # Actual Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-check-line me-2"
              span "Actual Name"
            end
            f.input :actual,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter actual/standard name..."
                    }
          end

          # Ethiopian Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-global-line me-2"
              span "Ethiopian Name"
            end
            f.input :ethiopian,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter Ethiopian name (e.g., Abreham)..."
                    }
          end
        end

        # Actions Section with dynamic button text
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            if f.object.new_record?
              f.action :submit,
                       label: "Create Mapping",
                       class: "materio-btn-primary"
            else
              f.action :submit,
                       label: "Update Mapping",
                       class: "materio-btn-primary"
            end
            f.action :cancel,
                     label: "Cancel",
                     class: "materio-btn-secondary"
          end
        end
      end
    end
  end

  show do
    # Custom CSS for Materio UI
    style do
      raw("
        .materio-avatar {
          width: 5rem;
          height: 5rem;
          border-radius: 50%;
          border: 3px solid #696cff;
          margin: 0 auto 1.5rem;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .materio-metric-card {
          background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
          border-radius: 1rem;
          padding: 1.5rem;
          color: white;
          text-align: center;
          box-shadow: 0 0.5rem 1rem rgba(105, 108, 255, 0.3);
        }
        .materio-metric-value {
          font-size: 2rem;
          font-weight: 700;
          margin-bottom: 0.5rem;
        }
        .materio-metric-label {
          font-size: 0.875rem;
          opacity: 0.9;
        }
        .tradition-badge {
          padding: 0.5rem 1rem;
          border-radius: 2rem;
          font-weight: 600;
          font-size: 0.875rem;
          margin: 0.25rem;
          display: inline-block;
        }
        .tradition-jewish { background: #ffd700; color: #000; }
        .tradition-christian { background: #007bff; color: #fff; }
        .tradition-muslim { background: #28a745; color: #fff; }
        .tradition-actual { background: #6c757d; color: #fff; }
        .tradition-ethiopian { background: #fd7e14; color: #fff; }
      ")
    end

    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-center" do
        div do
          h1 "Name Mapping Details", class: "mb-2 text-primary"
          para "View detailed information about this religious name mapping", class: "text-muted mb-0"
        end
        div class: "d-flex gap-2" do
          link_to "Edit Mapping", edit_admin_name_mapping_path(name_mapping), class: "btn btn-primary"
          link_to "Back to Name Mappings", admin_name_mappings_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "row g-4" do
      # Name Mapping Profile Card
      div class: "col-lg-4" do
        div class: "card h-100" do
          div class: "card-body text-center p-4" do
            div class: "materio-avatar" do
              i class: "ri ri-translate text-primary", style: "font-size: 2rem;"
            end
            h3 class: "mb-2" do name_mapping.internal_id end
            div class: "mb-3" do
              span class: "badge bg-primary fs-6" do "ID: #{name_mapping.id}" end
            end
            p class: "text-muted mb-0" do "Religious name mapping across traditions" end
          end
        end
      end

      # Name Mapping Information Card
      div class: "col-lg-8" do
        div class: "card h-100" do
          div class: "card-header bg-primary text-white" do
            h5 class: "mb-0" do
              i class: "ri ri-information-line me-2"
              "Name Variations"
            end
          end
          div class: "card-body" do
            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-star-line text-warning me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Jewish Name" end
                    div class: "fw-semibold" do name_mapping.jewish end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-cross-line text-primary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Christian Name" end
                    div class: "fw-semibold" do name_mapping.christian end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-moon-line text-success me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Muslim Name" end
                    div class: "fw-semibold" do name_mapping.muslim end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-check-line text-secondary me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Actual Name" end
                    div class: "fw-semibold" do name_mapping.actual end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "d-flex align-items-center p-3 bg-light rounded" do
                  i class: "ri ri-global-line text-warning me-3 fs-4"
                  div do
                    div class: "text-muted small" do "Ethiopian Name" end
                    div class: "fw-semibold" do name_mapping.ethiopian end
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-metric-card" do
                  div class: "materio-metric-value" do name_mapping.id end
                  div class: "materio-metric-label" do "Mapping ID" end
                end
              end
            end

            # All Traditions Display
            div class: "mt-4 pt-4 border-top" do
              h6 class: "mb-3" do "All Name Variations" end
              div class: "d-flex flex-wrap" do
                span class: "tradition-badge tradition-jewish" do "Jewish: #{name_mapping.jewish}" end
                span class: "tradition-badge tradition-christian" do "Christian: #{name_mapping.christian}" end
                span class: "tradition-badge tradition-muslim" do "Muslim: #{name_mapping.muslim}" end
                span class: "tradition-badge tradition-actual" do "Actual: #{name_mapping.actual}" end
                span class: "tradition-badge tradition-ethiopian" do "Ethiopian: #{name_mapping.ethiopian}" end
              end
            end
          end
        end
      end
    end
  end

  # Action items for the index page
  action_item :download_template, only: :index do
    link_to '📥 Download Template', download_template_admin_name_mappings_path, class: 'button'
  end

  action_item :upload_excel, only: :index do
    link_to '📤 Upload Excel File', upload_excel_admin_name_mappings_path, class: 'button'
  end

  # Custom action to download Excel template
  collection_action :download_template, method: :get do
    require 'csv'

    csv_data = CSV.generate do |csv|
      csv << ['Internal ID', 'Jewish', 'Christian', 'Muslim', 'Actual', 'Ethiopian']
      csv << ['person_abraham', 'Avraham', 'Abraham', 'Ibrahim', 'Avraham', 'Abreham']
      csv << ['person_moses', 'Moshe', 'Moses', 'Musa', 'Moshe', 'Muses']
      csv << ['god_yhwh', 'YHWH', 'LORD', 'Allah', 'YHWH', 'Egziabher']
    end

    send_data csv_data, filename: "name_mappings_template.csv", type: 'text/csv'
  end

  # Custom action to show upload page
  collection_action :upload_excel, method: :get do
    render 'admin/name_mappings/upload_excel'
  end

  # Custom action to update mappings from Excel
  collection_action :update_mappings_from_excel, method: :post do
    Rails.logger.info "=== UPLOAD ACTION CALLED ==="
    Rails.logger.info "Params: #{params.inspect}"

    begin
      if params[:excel_file].present?
        file = params[:excel_file]
        Rails.logger.info "File uploaded: #{file.original_filename}"

        # Read Excel file using Roo gem
        require 'roo'
        spreadsheet = Roo::Spreadsheet.open(file.path)
        sheet = spreadsheet.sheet(0)

        Rails.logger.info "Processing sheet with #{sheet.last_row} rows"

        # Use transaction to ensure atomicity
        ActiveRecord::Base.transaction do
          # Clear existing mappings
          NameMapping.delete_all
          Rails.logger.info "Cleared existing mappings"

          # Process each row (skip header)
          processed_count = 0
          (2..sheet.last_row).each do |row_number|
            row = sheet.row(row_number)
            next if row.all?(&:nil?) # Skip empty rows

            # Map columns to fields
            internal_id = row[0]&.to_s&.strip
            jewish = row[1]&.to_s&.strip
            christian = row[2]&.to_s&.strip
            muslim = row[3]&.to_s&.strip
            actual = row[4]&.to_s&.strip
            ethiopian = row[5]&.to_s&.strip

            # Create mapping if internal_id is present
            if internal_id.present?
              NameMapping.create!(
                internal_id: internal_id,
                jewish: jewish,
                christian: christian,
                muslim: muslim,
                actual: actual,
                ethiopian: ethiopian
              )
              processed_count += 1
              Rails.logger.info "Created mapping: #{internal_id}"
            end
          end

          Rails.logger.info "Processed #{processed_count} mappings"

          # If we reach here, transaction was successful
          redirect_to admin_name_mappings_path, notice: "Successfully updated #{processed_count} name mappings from Excel file."
        end
      else
        Rails.logger.info "No file uploaded"
        redirect_to admin_name_mappings_path, alert: "No file uploaded."
      end
    rescue => e
      Rails.logger.error "Error processing Excel file: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to admin_name_mappings_path, alert: "Error processing Excel file: #{e.message}"
    end
  end
end
