ActiveAdmin.register User do
  permit_params :email, :full_name, :role

  # Custom page title
  menu label: "Users", priority: 3

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "User Management", class: "mb-2"
      para "Manage all registered users and their roles", class: "text-muted"
    end


    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Email", class: "form-label"
            input type: "text", name: "q[email_cont]", placeholder: "Search email...", class: "form-control", value: params.dig(:q, :email_cont)
          end
          div class: "col-md-3" do
            label "Full Name", class: "form-label"
            input type: "text", name: "q[full_name_cont]", placeholder: "Search name...", class: "form-control", value: params.dig(:q, :full_name_cont)
          end
          div class: "col-md-3" do
            label "Role", class: "form-label"
            select name: "q[role_eq]", class: "form-select" do
              option "All Roles", value: ""
              option "Admin", value: "2", selected: params.dig(:q, :role_eq) == "2"
              option "User", value: "0", selected: params.dig(:q, :role_eq) == "0"
              option "Moderator", value: "1", selected: params.dig(:q, :role_eq) == "1"
            end
          end
          div class: "col-md-3" do
            label "Status", class: "form-label"
            select name: "q[confirmed_at_not_null]", class: "form-select" do
              option "All Status", value: ""
              option "Active", value: "true", selected: params.dig(:q, :confirmed_at_not_null) == "true"
              option "Pending", value: "false", selected: params.dig(:q, :confirmed_at_not_null) == "false"
            end
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterUsers()" do
            "Filter"
          end
          a href: admin_users_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterUsers() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_users_path}';

          var email = document.querySelector('input[name=\"q[email_cont]\"]').value;
          var fullName = document.querySelector('input[name=\"q[full_name_cont]\"]').value;
          var role = document.querySelector('select[name=\"q[role_eq]\"]').value;
          var status = document.querySelector('select[name=\"q[confirmed_at_not_null]\"]').value;

          if (email) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[email_cont]';
            input.value = email;
            form.appendChild(input);
          }

          if (fullName) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[full_name_cont]';
            input.value = fullName;
            form.appendChild(input);
          }

          if (role && role !== 'All Roles') {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[role_eq]';
            input.value = role;
            form.appendChild(input);
          }

          if (status && status !== 'All Status') {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[confirmed_at_not_null]';
            input.value = status;
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
            th "USER", class: "fw-semibold"
            th "EMAIL", class: "fw-semibold"
            th "ROLE", class: "fw-semibold"
            th "STATUS", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          users.each do |user|
            tr do
              # USER column with avatar and name
              td do
                div class: "d-flex align-items-center" do
                  div class: "avatar avatar-sm me-3" do
                    img src: asset_path("avatars/#{(user.id % 20) + 1}.png"),
                        alt: user.full_name || user.email,
                        class: "rounded-circle"
                  end
                  div do
                    div class: "fw-semibold" do
                      user.full_name || user.email.split('@').first.titleize
                    end
                    div class: "text-muted small" do
                      "@#{user.email.split('@').first}"
                    end
                  end
                end
              end

              # EMAIL column
              td do
                span class: "text-body" do
                  user.email
                end
              end

              # ROLE column with icon
              td do
                case user.role
                when 'admin'
                  div class: "d-flex align-items-center" do
                    i class: "ri ri-crown-line me-2 text-primary"
                    span "Admin"
                  end
                when 'user'
                  div class: "d-flex align-items-center" do
                    i class: "ri ri-user-line me-2 text-success"
                    span "User"
                  end
                else
                  div class: "d-flex align-items-center" do
                    i class: "ri ri-user-line me-2 text-secondary"
                    span user.role&.titleize || "User"
                  end
                end
              end

              # STATUS column with badge
              td do
                if user.confirmed?
                  span class: "badge bg-success" do
                    "Active"
                  end
                else
                  span class: "badge bg-warning" do
                    "Pending"
                  end
                end
              end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_user_path(user)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_user_path(user)}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_user_path(user)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :email
  filter :full_name
  filter :role
  filter :created_at
  filter :confirmed_at

  form do |f|
    div class: "page-header mb-4" do
      h1 "Edit User", class: "mb-2"
      para "Update user information and permissions", class: "text-muted"
    end

    div class: "card" do
      div class: "card-body" do
    f.inputs do
          f.input :email, class: "form-control"
          f.input :full_name, class: "form-control"
          f.input :role, as: :select, collection: User.roles.keys, class: "form-control"
        end
        f.actions do
          f.action :submit, label: "Update User", class: "btn btn-primary"
          f.action :cancel, label: "Cancel", class: "btn btn-secondary"
        end
      end
    end
  end

  show do
    div class: "page-header mb-4" do
      h1 "User Details", class: "mb-2"
      para "View detailed information about this user", class: "text-muted"
    end

    div class: "card" do
      div class: "card-body" do
        div class: "d-flex align-items-center mb-4" do
          div class: "avatar avatar-lg me-3" do
            img src: asset_path("avatars/#{(user.id % 20) + 1}.png"),
                alt: user.full_name || user.email,
                class: "rounded-circle"
          end
          div do
            h4 class: "mb-1" do
              user.full_name || user.email.split('@').first.titleize
            end
            p class: "text-muted mb-0" do
              user.email
            end
            span class: "badge bg-#{user.confirmed? ? 'success' : 'warning'}" do
              user.confirmed? ? "Active" : "Pending"
            end
          end
        end

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
