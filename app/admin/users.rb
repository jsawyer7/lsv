ActiveAdmin.register User do
  permit_params :email, :full_name, :role

  index do
    selectable_column
    id_column
    column :email
    column :full_name
    column :role
    column :created_at
    column :confirmed_at
    actions
  end

  filter :email
  filter :full_name
  filter :role
  filter :created_at
  filter :confirmed_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :full_name
      f.input :role, as: :select, collection: User.roles.keys
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :email
      row :full_name
      row :role
      row :created_at
      row :updated_at
      row :confirmed_at
      row :provider
      row :uid
    end
  end

  # Custom action to resend confirmation instructions
  member_action :resend_confirmation, method: :post do
    resource.resend_confirmation_instructions
    redirect_to admin_user_path(resource), notice: 'Confirmation instructions have been resent.'
  end

  action_item :resend_confirmation, only: :show do
    unless resource.confirmed?
      link_to 'Resend Confirmation', resend_confirmation_admin_user_path(resource), method: :post
    end
  end
end 