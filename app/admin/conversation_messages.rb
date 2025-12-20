ActiveAdmin.register ConversationMessage do
  permit_params :conversation_id, :role, :content, :position

  menu label: "VeriTalk Messages", priority: 5, parent: "VeriTalk Conversations"

  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "VeriTalk Messages", class: "mb-2"
      para "View all messages from VeriTalk conversations", class: "text-muted"
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "ID"
            th "Conversation"
            th "Role"
            th "Content"
            th "Position"
            th "Created At"
            th "Actions"
          end
        end
        tbody do
          conversation_messages.each do |message|
            tr do
              td message.id
              td do
                link_to "Conversation ##{message.conversation_id}", admin_conversation_path(message.conversation), class: "text-primary"
              end
              td do
                span class: "badge bg-#{message.role == 'user' ? 'primary' : 'secondary'}" do
                  message.role.titleize
                end
              end
              td do
                div class: "fw-semibold" do
                  truncate(message.content, length: 80)
                end
              end
              td message.position
              td message.created_at.strftime("%B %d, %Y %I:%M %p")
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_conversation_message_path(message)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{admin_conversation_message_path(message)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :conversation
  filter :role, as: :select, collection: [['User', 'user'], ['Assistant', 'assistant']]
  filter :position
  filter :created_at

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Message ##{conversation_message.id}", class: "mb-1 fw-bold text-dark"
        p "#{conversation_message.created_at.strftime('%b %d, %Y, %I:%M %p')}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Message", edit_admin_conversation_message_path(conversation_message), class: "btn btn-primary px-3 py-2"
        link_to "Back to Messages", admin_conversation_messages_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "card-body p-4" do
            div class: "mb-4" do
              div class: "d-flex justify-content-between align-items-center mb-3" do
                span class: "badge bg-#{conversation_message.role == 'user' ? 'primary' : 'secondary'} fs-6" do
                  conversation_message.role.titleize
                end
                span class: "text-muted" do
                  "Position: #{conversation_message.position}"
                end
              end

              div class: "materio-content-area" do
                div class: "fw-semibold fs-5 text-dark" do
                  simple_format(conversation_message.content)
                end
              end
            end

            div class: "row g-3" do
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-chat-3-line me-2"
                    "Conversation"
                  end
                  div class: "fw-semibold text-dark" do
                    link_to "Conversation ##{conversation_message.conversation_id}", admin_conversation_path(conversation_message.conversation), class: "text-primary"
                  end
                end
              end
              div class: "col-md-6" do
                div class: "materio-info-item" do
                  div class: "text-muted small fw-semibold mb-2" do
                    i class: "ri ri-calendar-line me-2"
                    "Created At"
                  end
                  div class: "fw-semibold text-dark" do
                    conversation_message.created_at.strftime("%B %d, %Y at %I:%M %p")
                  end
                end
              end
            end
          end
        end
      end

      div class: "col-lg-4" do
        div class: "materio-card" do
          div class: "card-body p-4" do
            div class: "materio-info-item" do
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Message ID:" end
                span class: "fw-semibold" do conversation_message.id end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Role:" end
                span class: "fw-semibold" do
                  span class: "badge bg-#{conversation_message.role == 'user' ? 'primary' : 'secondary'}" do
                    conversation_message.role.titleize
                  end
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Position:" end
                span class: "fw-semibold" do conversation_message.position end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Content Length:" end
                span class: "fw-semibold" do "#{conversation_message.content.length} characters" end
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
            h1 "Create Message", class: "mb-2 text-primary"
          else
            h1 "Edit Message", class: "mb-2 text-primary"
          end
        end
        div do
          link_to "Back to Messages", admin_conversation_messages_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-body p-5" do
        f.inputs do
          f.input :conversation, as: :select, collection: Conversation.all.map { |c| ["##{c.id} - #{truncate(c.topic, length: 40)}", c.id] }
          f.input :role, as: :select, collection: [['User', 'user'], ['Assistant', 'assistant']]
          f.input :content, as: :text, input_html: { rows: 10 }
          f.input :position
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
end
