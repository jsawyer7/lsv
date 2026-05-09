ActiveAdmin.register VeritalkValidator do
  permit_params :name, :description, :system_prompt, :is_active, :version, :purpose, :created_by_type, :created_by_id

  menu false # Menu is handled manually in sidebar

  controller do
    layout "active_admin_custom"

    def create
      @validator = VeritalkValidator.new(permitted_params[:veritalk_validator])
      @validator.created_by = current_admin_user if respond_to?(:current_admin_user)

      if @validator.save
        redirect_to admin_veritalk_validator_path(@validator), notice: 'Validator created successfully!'
      else
        render :new
      end
    end
  end

  index do
    div class: "page-header mb-4" do
      h1 "VeriTalk Validators", class: "mb-2"
      para "Manage and test VeriTalk system prompts", class: "text-muted"
    end

    current_forensic = VeritalkValidator.current_forensic
    current_conversational = VeritalkValidator.current_conversational
    preview_btn = lambda do |style|
      link_to "Preview active prompts", preview_current_admin_veritalk_validators_path,
              class: "btn btn-sm btn-#{style}",
              target: "_blank"
    end

    if current_forensic
      div class: "alert alert-info mb-3" do
        div class: "d-flex align-items-center justify-content-between flex-wrap gap-2" do
          div class: "d-flex align-items-center" do
            i class: "ri ri-information-line me-2", style: "font-size: 20px;"
            div do
              strong "Active forensic pass: "
              span "#{current_forensic.name} (v#{current_forensic.version}, ID: #{current_forensic.id})"
            end
          end
          div do
            preview_btn.call("info")
          end
        end
      end
    else
      div class: "alert alert-warning mb-3" do
        div class: "d-flex align-items-center justify-content-between flex-wrap gap-2" do
          div do
            strong "No active forensic validator"
          end
          div do
            preview_btn.call("warning")
          end
        end
      end
    end

    if current_conversational
      div class: "alert alert-success mb-4" do
        div class: "d-flex align-items-center justify-content-between flex-wrap gap-2" do
          div class: "d-flex align-items-center" do
            i class: "ri ri-chat-smile-line me-2", style: "font-size: 20px;"
            div do
              strong "Active conversational pass: "
              span "#{current_conversational.name} (v#{current_conversational.version}, ID: #{current_conversational.id})"
            end
          end
          div do
            preview_btn.call("success")
          end
        end
      end
    else
      div class: "alert alert-warning mb-4" do
        div class: "d-flex align-items-center justify-content-between flex-wrap gap-2" do
          div do
            strong "No active conversational validator"
          end
          div do
            preview_btn.call("warning")
          end
        end
      end
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "ID"
            th "Name"
            th "Purpose"
            th "Version"
            th "Status"
            th "Created By"
            th "Created At"
            th "Actions"
          end
        end
        tbody do
          veritalk_validators.each do |validator|
            tr do
              td validator.id
              td do
                div class: "fw-semibold" do
                  validator.name
                end
                if validator.description.present?
                  div class: "text-muted small mt-1" do
                    truncate(validator.description, length: 60)
                  end
                end
              end
              td do
                span class: "badge bg-#{validator.purpose == 'forensic' ? 'dark' : 'primary'}" do
                  validator.purpose.titleize
                end
              end
              td do
                span class: "badge bg-secondary" do
                  "v#{validator.version}"
                end
              end
              td do
                if validator.is_active?
                  span class: "badge bg-success" do
                    "Active"
                  end
                else
                  span class: "badge bg-secondary" do
                    "Inactive"
                  end
                end
              end
              td do
                if validator.created_by
                  validator.created_by_type == "User" ? validator.created_by.email : "Admin"
                else
                  span class: "text-muted" do "System" end
                end
              end
              td validator.created_at.strftime("%B %d, %Y %I:%M %p")
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_veritalk_validator_path(validator)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_veritalk_validator_path(validator)}' class='btn btn-sm btn-outline-info'>Edit</a>
                  <a href='#{admin_veritalk_validator_path(validator)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 veritalk_validator.name, class: "mb-1 fw-bold text-dark"
        p "#{veritalk_validator.created_at.strftime('%b %d, %Y, %I:%M %p')}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        unless veritalk_validator.is_active?
          link_to "Activate This Validator", activate_admin_veritalk_validator_path(veritalk_validator),
                  method: :post,
                  class: "btn btn-success px-3 py-2",
                  data: { confirm: "This will deactivate other validators with the same purpose (#{veritalk_validator.purpose}). Continue?" }
        end
        link_to "Preview Current Prompt", preview_current_admin_veritalk_validators_path,
                class: "btn btn-info px-3 py-2",
                target: "_blank"
        link_to "Test Validator", test_admin_veritalk_validator_path(veritalk_validator),
                class: "btn btn-primary px-3 py-2",
                target: "_blank"
        link_to "Edit", edit_admin_veritalk_validator_path(veritalk_validator), class: "btn btn-outline-primary px-3 py-2"
        link_to "Back", admin_veritalk_validators_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      # Left Column - Validator Info
      div class: "col-lg-4" do
        div class: "materio-card" do
          div class: "card-body p-4" do
            div class: "text-center mb-4" do
              div class: "materio-icon primary mb-3" do
                i class: "ri ri-file-code-line"
              end
              h3 veritalk_validator.name, class: "mb-2 fw-bold"
              p "Validator ID ##{veritalk_validator.id}", class: "text-muted mb-3"

              div class: "mb-4" do
                if veritalk_validator.is_active?
                  div class: "alert alert-success" do
                    i class: "ri ri-checkbox-circle-line me-2"
                    "This validator is currently ACTIVE"
                  end
                else
                  div class: "alert alert-secondary" do
                    i class: "ri ri-information-line me-2"
                    "This validator is INACTIVE"
                  end
                end
              end
            end

            div class: "materio-info-item" do
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Purpose:" end
                span class: "fw-semibold" do veritalk_validator.purpose.titleize end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Version:" end
                span class: "fw-semibold" do "v#{veritalk_validator.version}" end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Created By:" end
                span class: "fw-semibold" do
                  veritalk_validator.created_by ? (veritalk_validator.created_by_type == "User" ? veritalk_validator.created_by.email : "Admin") : "System"
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Created:" end
                span class: "fw-semibold" do veritalk_validator.created_at.strftime("%B %d, %Y") end
              end
              div class: "d-flex justify-content-between align-items-center" do
                span class: "text-muted small fw-semibold" do "Updated:" end
                span class: "fw-semibold" do veritalk_validator.updated_at.strftime("%B %d, %Y") end
              end
            end

            if veritalk_validator.description.present?
              div class: "mt-3 pt-3 border-top" do
                div class: "text-muted small fw-semibold mb-2" do "Description:" end
                div class: "fw-semibold text-dark" do simple_format(veritalk_validator.description) end
              end
            end
          end
        end
      end

      # Right Column - System Prompt
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-file-text-line me-2"
              "System Prompt"
            end
          end
          div class: "card-body p-4" do
            div class: "bg-light p-3 rounded" do
              pre class: "mb-0 text-dark", style: "white-space: pre-wrap; font-family: 'Courier New', monospace; font-size: 13px; line-height: 1.6;" do
                veritalk_validator.system_prompt
              end
            end
            div class: "mt-3" do
              small class: "text-muted" do
                "Character count: #{veritalk_validator.system_prompt.length} | Word count: #{veritalk_validator.system_prompt.split.size}"
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
          if f.object.new_record?
            h1 "Create Validator", class: "mb-2 text-primary"
            para "Add new VeriTalk validator prompt", class: "text-muted mb-0"
          else
            h1 "Edit Validator", class: "mb-2 text-primary"
            para "Update validator information", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Validators", admin_veritalk_validators_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-file-code-line me-2"
          "Validator Information"
        end
      end
      div class: "card-body p-5" do
        f.inputs do
          f.input :name, input_html: { class: "form-control" }
          f.input :purpose, as: :select,
                  collection: VeritalkValidator::PURPOSES.map { |p| [p.titleize, p] },
                  include_blank: false,
                  input_html: { class: "form-control" }
          f.input :description, as: :text, input_html: { rows: 3, class: "form-control" }
          f.input :system_prompt, as: :text,
                  input_html: {
                    rows: 20,
                    class: "form-control font-monospace",
                    style: "font-family: 'Courier New', monospace; font-size: 13px;"
                  }
          f.input :version, input_html: { class: "form-control", min: 1 }
          f.input :is_active, as: :boolean
        end

        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit, class: "materio-btn-primary"
            f.action :cancel, class: "materio-btn-secondary"
          end
        end
      end
    end
  end

  filter :name
  filter :purpose
  filter :is_active
  filter :version
  filter :created_at

  member_action :activate, method: :post do
    resource.activate!
    redirect_to admin_veritalk_validator_path(resource), notice: "Validator activated successfully!"
  end

  member_action :test, method: :get do
    redirect_to veritalk_path, notice: "Open VeriTalk in a new tab to test this validator. Make sure it's activated first!"
  end

  collection_action :preview_current, method: :get do
    @current_forensic = VeritalkValidator.current_forensic
    @current_conversational = VeritalkValidator.current_conversational

    begin
      preview_service = VeritalkChatService.new(
        user: User.first || User.new(email: "test@test.com"),
        conversation: Conversation.first || Conversation.new(user: User.first || User.new(email: "test@test.com"), topic: "Test"),
        user_message_text: "test"
      )
      @fallback_forensic_prompt = preview_service.send(:default_system_prompt)
      @fallback_conversational_prompt = preview_service.send(:default_conversational_system_prompt)
    rescue => e
      @fallback_forensic_prompt = "Error loading default forensic prompt: #{e.message}"
      @fallback_conversational_prompt = "Error loading default conversational prompt: #{e.message}"
    end

    render layout: "active_admin_custom"
  end
end

