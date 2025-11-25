ActiveAdmin.register PartyType do
  permit_params :code, :label, :description

  menu parent: "Data Tables", label: "Party Types", priority: 9

  controller do
    layout "active_admin_custom"
  end
  
  config.sort_order = 'code_asc'

  action_item :new_party_type, only: :index do
    link_to "Add Party Type", new_admin_party_type_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Party Type Management", class: "mb-2"
          para "Manage party types for Addressed Party and Responsible Party classifications", class: "text-muted"
        end
        div do
          link_to "Add Party Type", new_admin_party_type_path, class: "btn btn-primary"
        end
      end
    end

    div class: "table-responsive" do
      table_for collection, class: "table table-striped table-hover" do
        column "Code", :code, sortable: :code
        column "Label", :label, sortable: :label
        column "Description", :description
        column "Created", :created_at, sortable: :created_at do |party_type|
          party_type.created_at.strftime("%Y-%m-%d %H:%M") if party_type.created_at
        end
        actions
      end
    end
  end

  form do |f|
    f.semantic_errors *f.object.errors.keys
    
    f.inputs "Party Type Details" do
      f.input :code, label: "Code", hint: "Unique code (e.g., ISRAEL, GENTILES, CHURCH)"
      f.input :label, label: "Label", hint: "Display name"
      f.input :description, label: "Description", as: :text, input_html: { rows: 3 }
    end
    
    f.actions
  end

  show do
    attributes_table do
      row :code
      row :label
      row :description
      row :created_at
      row :updated_at
    end
  end
end

