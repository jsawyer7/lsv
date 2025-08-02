ActiveAdmin.register NameMapping do
  permit_params :internal_id, :jewish, :christian, :muslim, :actual, :ethiopian

  index do
    selectable_column
    id_column
    column :internal_id
    column :jewish
    column :christian
    column :muslim
    column :actual
    column :ethiopian
    column :created_at
    actions
  end

  filter :internal_id
  filter :jewish
  filter :christian
  filter :muslim
  filter :actual
  filter :ethiopian
  filter :created_at

  form do |f|
    f.inputs do
      f.input :internal_id
      f.input :jewish
      f.input :christian
      f.input :muslim
      f.input :actual
      f.input :ethiopian
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :internal_id
      row :jewish
      row :christian
      row :muslim
      row :actual
      row :ethiopian
      row :created_at
      row :updated_at
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