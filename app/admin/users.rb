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

    # Page Header
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Edit User", class: "mb-1 fw-bold text-dark"
        p "Update user information and permissions", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Back to Users", admin_users_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    # Main Form Content
    div class: "materio-form-card" do
      div class: "materio-form-header" do
        h5 class: "mb-0 fw-semibold" do
          i class: "ri ri-edit-line me-2"
          "User Information"
        end
      end
      div class: "card-body p-4" do
    f.inputs do
          # Email Display (Read-only)
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-mail-line me-2"
              "Email Address"
            end
            div class: "materio-user-info" do
              div class: "materio-user-avatar" do
                f.object.email.first.upcase
              end
              div do
                div class: "fw-semibold text-dark" do f.object.email end
                div class: "text-muted small" do "Email cannot be changed" end
              end
            end
          end

          # Full Name Input
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-user-line me-2"
              "Full Name"
            end
            f.input :full_name,
                    class: "materio-form-control",
                    label: false,
                    input_html: {
                      class: "materio-form-control",
                      placeholder: "Enter user's full name..."
                    }
          end

          # Role Selection
          div class: "materio-form-group" do
            div class: "materio-form-label" do
              i class: "ri ri-shield-user-line me-2"
              "User Role"
            end
            f.input :role,
                    as: :select,
                    collection: User.roles.keys.map { |role| [role.titleize, role] },
                    class: "materio-form-control materio-form-select",
                    label: false,
                    input_html: { class: "materio-form-control materio-form-select" }
          end
        end
        # Actions Section
        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit,
                     label: "Update User",
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

    # Page Header
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "User ID ##{user.id}", class: "mb-1 fw-bold text-dark"
        p "#{user.created_at.strftime('%b %d, %Y, %I:%M %p')} (#{Time.zone.name})", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit User", edit_admin_user_path(user), class: "btn btn-primary px-3 py-2"
        link_to "Back to Users", admin_users_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      # Left Column - User Profile Card
      div class: "col-lg-4" do
        div class: "materio-card" do
          div class: "card-body p-4" do
            # Profile Section
            div class: "text-center mb-4" do
              div class: "materio-avatar" do
            img src: asset_path("avatars/#{(user.id % 20) + 1}.png"),
                alt: user.full_name || user.email,
                    class: "w-100 h-100 rounded-circle"
          end
              h3 class: "mb-2 fw-bold" do
              user.full_name || user.email.split('@').first.titleize
            end
              p class: "text-muted mb-3" do user.email end

              # Role Badge
              span class: "badge bg-#{user.role == 'admin' ? 'primary' : 'success'} mb-3" do
                case user.role
                when 'admin'
                  "Administrator"
                when 'user'
                  "User"
                else
                  user.role&.titleize || "User"
                end
              end

              # Key Metrics
              div class: "row g-3 mb-4" do
                div class: "col-6" do
                  div class: "text-center" do
                    div class: "materio-icon success mb-2" do
                      i class: "ri ri-check-line"
                    end
                    div class: "fw-bold text-dark" do
                      user.claims.count
                    end
                    div class: "text-muted small" do "Claims Made" end
                  end
                end
                div class: "col-6" do
                  div class: "text-center" do
                    div class: "materio-icon warning mb-2" do
                      i class: "ri ri-calendar-line"
                    end
                    div class: "fw-bold text-dark" do user.created_at.strftime("%b %d") end
                    div class: "text-muted small" do "Member Since" end
                  end
                end
              end
            end

            # Details Section
            div class: "materio-info-item" do
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Username:" end
                span class: "fw-semibold" do "@#{user.email.split('@').first}" end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Email:" end
                span class: "fw-semibold" do user.email end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Status:" end
            span class: "badge bg-#{user.confirmed? ? 'success' : 'warning'}" do
              user.confirmed? ? "Active" : "Pending"
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Role:" end
                span class: "fw-semibold" do
                  case user.role
                  when 'admin'
                    "Administrator"
                  when 'user'
                    "User"
                  else
                    user.role&.titleize || "User"
                  end
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Contact:" end
                span class: "fw-semibold" do "N/A" end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Languages:" end
                span class: "fw-semibold" do "English" end
              end
              div class: "d-flex justify-content-between align-items-center" do
                span class: "text-muted small fw-semibold" do "Country:" end
                span class: "fw-semibold" do "USA" end
              end
            end

            # Action Buttons
            div class: "d-flex gap-2 mt-3" do
              link_to "Edit", edit_admin_user_path(user), class: "btn btn-primary flex-fill"
              link_to "Delete", admin_user_path(user), method: :delete,
                      data: { confirm: "Are you sure you want to delete this user? This action cannot be undone." },
                      class: "btn btn-outline-danger flex-fill"
            end
          end
        end
      end

      # Right Column - Information Cards
      div class: "col-lg-8" do
        div class: "row g-4" do
          # User Information Card
          div class: "col-12" do
            div class: "materio-card" do
              div class: "materio-header" do
                h5 class: "mb-0 fw-semibold" do
                  i class: "ri ri-user-settings-line me-2"
                  "User Information"
                end
              end
              div class: "card-body p-4" do
                div class: "row g-3" do
                  div class: "col-md-6" do
                    div class: "materio-info-item" do
                      div class: "text-muted small fw-semibold mb-2" do
                        i class: "ri ri-mail-line me-2"
                        "Email Address"
                      end
                      div class: "fw-semibold text-dark" do user.email end
                    end
                  end
                  div class: "col-md-6" do
                    div class: "materio-info-item" do
                      div class: "text-muted small fw-semibold mb-2" do
                        i class: "ri ri-user-line me-2"
                        "Full Name"
                      end
                      div class: "fw-semibold text-dark" do user.full_name || "Not provided" end
                    end
                  end
                  div class: "col-md-6" do
                    div class: "materio-info-item" do
                      div class: "text-muted small fw-semibold mb-2" do
                        i class: "ri ri-calendar-line me-2"
                        "Member Since"
                      end
                      div class: "fw-semibold text-dark" do user.created_at.strftime("%B %d, %Y") end
                    end
                  end
                  div class: "col-md-6" do
                    div class: "materio-info-item" do
                      div class: "text-muted small fw-semibold mb-2" do
                        i class: "ri ri-shield-check-line me-2"
                        "Account Status"
                      end
                      div class: "fw-semibold" do
                        span class: "badge bg-#{user.confirmed? ? 'success' : 'warning'}" do
                          user.confirmed? ? "Verified" : "Pending Verification"
                        end
                      end
                    end
                  end
                  if user.provider.present?
                    div class: "col-md-6" do
                      div class: "materio-info-item" do
                        div class: "text-muted small fw-semibold mb-2" do
                          i class: "ri ri-login-box-line me-2"
                          "Login Provider"
                        end
                        div class: "fw-semibold text-dark" do user.provider.titleize end
                      end
                    end
                  end
                  if user.about.present?
                    div class: "col-12" do
                      div class: "materio-info-item" do
                        div class: "text-muted small fw-semibold mb-2" do
                          i class: "ri ri-file-text-line me-2"
                          "About"
                        end
                        div class: "fw-semibold text-dark" do user.about end
                      end
                    end
                  end
                end
              end
            end
          end

          # Information Cards Grid
          div class: "col-md-6" do
            div class: "materio-metric-card" do
              div class: "materio-icon success" do
                i class: "ri ri-file-text-line"
              end
              h6 "Total Claims", class: "mb-2 fw-semibold"
              div class: "fw-bold text-dark mb-2" do
                user.claims.count
              end
              p "Claims submitted by this user", class: "text-muted small mb-0"
            end
          end

          div class: "col-md-6" do
            div class: "materio-metric-card" do
              div class: "materio-icon warning" do
                i class: "ri ri-calendar-line"
              end
              h6 "Member Since", class: "mb-2 fw-semibold"
              div class: "fw-bold text-dark mb-2" do
                user.created_at.strftime("%B %d, %Y")
              end
              p "When user joined the platform", class: "text-muted small mb-0"
            end
          end

          div class: "col-md-6" do
            div class: "materio-metric-card" do
              div class: "materio-icon info" do
                i class: "ri ri-shield-check-line"
              end
              h6 "Account Status", class: "mb-2 fw-semibold"
              div class: "badge bg-#{user.confirmed? ? 'success' : 'warning'} mb-2" do
                user.confirmed? ? "Active" : "Pending"
              end
              p "Current account verification status", class: "text-muted small mb-0"
          end
        end

          div class: "col-md-6" do
            div class: "materio-metric-card" do
              div class: "materio-icon primary" do
                i class: "ri ri-user-line"
              end
              h6 "User Role", class: "mb-2 fw-semibold"
              div class: "fw-bold text-dark mb-2" do
                case user.role
                when 'admin'
                  "Administrator"
                when 'user'
                  "User"
                else
                  user.role&.titleize || "User"
                end
              end
              p "User's permission level", class: "text-muted small mb-0"
            end
          end
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
