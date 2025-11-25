ActiveAdmin.register GenreType do
  permit_params :code, :label, :description

  menu parent: "Data Tables", label: "Genre Types", priority: 10

  controller do
    layout "active_admin_custom"
  end
  
  config.sort_order = 'code_asc'

  action_item :new_genre_type, only: :index do
    link_to "Add Genre Type", new_admin_genre_type_path, class: "btn btn-primary"
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Genre Type Management", class: "mb-2"
          para "Manage genre types for text content classification", class: "text-muted"
        end
        div do
          link_to "Add Genre Type", new_admin_genre_type_path, class: "btn btn-primary"
        end
      end
    end

    div class: "table-responsive" do
      table_for collection, class: "table table-striped table-hover" do
        column "Code", :code, sortable: :code
        column "Label", :label, sortable: :label
        column "Description", :description
        column "Created", :created_at, sortable: :created_at do |genre_type|
          genre_type.created_at.strftime("%Y-%m-%d %H:%M") if genre_type.created_at
        end
        actions
      end
    end
  end

  form do |f|
    f.semantic_errors *f.object.errors.keys
    
    f.inputs "Genre Type Details" do
      f.input :code, label: "Code", hint: "Unique code (e.g., NARRATIVE, PROPHECY, EPISTLE_LETTER)"
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

