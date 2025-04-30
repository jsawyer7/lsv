ActiveAdmin.register Claim do
  permit_params :content, :evidence, :user_id

  index do
    selectable_column
    id_column
    column :content
    column :evidence
    column :user
    column :created_at
    actions
  end

  filter :content
  filter :evidence
  filter :user
  filter :created_at

  form do |f|
    f.inputs do
      f.input :user
      f.input :content
      f.input :evidence
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :content
      row :evidence
      row :user
      row :created_at
      row :updated_at
    end
  end
end 