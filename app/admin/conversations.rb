ActiveAdmin.register Conversation do
  permit_params :topic, :user_id, :summary, :rolling_summary, :message_count_since_summary, :last_summary_update_at

  menu label: "VeriTalk Conversations", priority: 4

  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "VeriTalk Conversations", class: "mb-2"
      para "Manage all VeriTalk conversations and their messages", class: "text-muted"
    end

    # Filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-4" do
            label "Topic", class: "form-label"
            input type: "text", name: "q[topic_cont]", placeholder: "Search topic...", class: "form-control", value: params.dig(:q, :topic_cont)
          end
          div class: "col-md-4" do
            label "User Email", class: "form-label"
            input type: "text", name: "q[user_email_cont]", placeholder: "Search user email...", class: "form-control", value: params.dig(:q, :user_email_cont)
          end
          div class: "col-md-4" do
            label "Created At", class: "form-label"
            div class: "row g-2" do
              div class: "col-6" do
                input type: "date", name: "q[created_at_gteq]", class: "form-control", value: params.dig(:q, :created_at_gteq), placeholder: "From"
              end
              div class: "col-6" do
                input type: "date", name: "q[created_at_lteq]", class: "form-control", value: params.dig(:q, :created_at_lteq), placeholder: "To"
              end
            end
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterConversations()" do
            "Filter"
          end
          a href: admin_conversations_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    script do
      raw("
        function filterConversations() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_conversations_path}';

          var topic = document.querySelector('input[name=\"q[topic_cont]\"]').value;
          var userEmail = document.querySelector('input[name=\"q[user_email_cont]\"]').value;
          var dateFrom = document.querySelector('input[name=\"q[created_at_gteq]\"]').value;
          var dateTo = document.querySelector('input[name=\"q[created_at_lteq]\"]').value;

          if (topic) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[topic_cont]';
            input.value = topic;
            form.appendChild(input);
          }

          if (userEmail) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[user_email_cont]';
            input.value = userEmail;
            form.appendChild(input);
          }

          if (dateFrom) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[created_at_gteq]';
            input.value = dateFrom;
            form.appendChild(input);
          }

          if (dateTo) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[created_at_lteq]';
            input.value = dateTo;
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
            th "ID"
            th "Topic"
            th "User"
            th "Messages"
            th "Created At"
            th "Last Updated"
            th "Actions"
          end
        end
        tbody do
          conversations.each do |conversation|
            tr do
              td conversation.id
              td do
                div class: "fw-semibold" do
                  truncate(conversation.topic, length: 50)
                end
              end
              td do
                if conversation.user
                  div class: "d-flex align-items-center" do
                    div class: "avatar avatar-sm me-2" do
                      img src: asset_path("avatars/#{(conversation.user.id % 20) + 1}.png"),
                          alt: conversation.user.full_name || conversation.user.email,
                          class: "rounded-circle"
                    end
                    div do
                      div class: "fw-semibold small" do
                        conversation.user.full_name || conversation.user.email.split('@').first.titleize
                      end
                      div class: "text-muted small" do
                        conversation.user.email
                      end
                    end
                  end
                else
                  span class: "text-muted" do "Unknown User" end
                end
              end
              td do
                span class: "badge bg-info" do
                  conversation.conversation_messages.count
                end
              end
              td conversation.created_at.strftime("%B %d, %Y %I:%M %p")
              td conversation.updated_at.strftime("%B %d, %Y %I:%M %p")
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_conversation_path(conversation)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{admin_conversation_path(conversation)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure you want to delete this conversation?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :topic
  filter :user
  filter :created_at
  filter :updated_at

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Conversation ##{conversation.id}", class: "mb-1 fw-bold text-dark"
        p "#{conversation.created_at.strftime('%b %d, %Y, %I:%M %p')}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Conversation", edit_admin_conversation_path(conversation), class: "btn btn-primary px-3 py-2"
        link_to "Back to Conversations", admin_conversations_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      # Left Column - Conversation Info
      div class: "col-lg-4" do
        div class: "materio-card" do
          div class: "card-body p-4" do
            div class: "text-center mb-4" do
              div class: "materio-icon primary mb-3" do
                i class: "ri ri-chat-3-line"
              end
              h3 truncate(conversation.topic, length: 40), class: "mb-2 fw-bold"
              p "Conversation ID ##{conversation.id}", class: "text-muted mb-3"

              div class: "row g-3 mb-4" do
                div class: "col-6" do
                  div class: "text-center" do
                    div class: "materio-icon success mb-2" do
                      i class: "ri ri-message-2-line"
                    end
                    div class: "fw-bold text-dark" do
                      conversation.conversation_messages.count
                    end
                    div class: "text-muted small" do "Messages" end
                  end
                end
                div class: "col-6" do
                  div class: "text-center" do
                    div class: "materio-icon warning mb-2" do
                      i class: "ri ri-file-list-line"
                    end
                    div class: "fw-bold text-dark" do
                      conversation.conversation_summaries.count
                    end
                    div class: "text-muted small" do "Summaries" end
                  end
                end
              end
            end

            div class: "materio-info-item" do
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "User:" end
                span class: "fw-semibold" do
                  if conversation.user
                    conversation.user.email
                  else
                    "N/A"
                  end
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Topic:" end
                span class: "fw-semibold" do truncate(conversation.topic, length: 30) end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Created:" end
                span class: "fw-semibold" do conversation.created_at.strftime("%B %d, %Y") end
              end
              div class: "d-flex justify-content-between align-items-center" do
                span class: "text-muted small fw-semibold" do "Updated:" end
                span class: "fw-semibold" do conversation.updated_at.strftime("%B %d, %Y") end
              end
            end

            if conversation.summary.present?
              div class: "mt-3 pt-3 border-top" do
                div class: "text-muted small fw-semibold mb-2" do "Summary:" end
                div class: "fw-semibold text-dark" do simple_format(conversation.summary) end
              end
            end

            # Rolling Summary Info
            div class: "mt-3 pt-3 border-top" do
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Messages Since Summary:" end
                span class: "fw-semibold" do
                  conversation.message_count_since_summary || 0
                end
              end
              if conversation.last_summary_update_at
                div class: "d-flex justify-content-between align-items-center" do
                  span class: "text-muted small fw-semibold" do "Last Summary Update:" end
                  span class: "fw-semibold" do conversation.last_summary_update_at.strftime("%b %d, %Y %I:%M %p") end
                end
              end
            end
          end
        end
      end

      # Right Column - Messages and Rolling Summary
      div class: "col-lg-8" do
        # Rolling Summary Section
        if conversation.rolling_summary.present?
          div class: "materio-card mb-4" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-file-list-line me-2"
                "Rolling Summary"
              end
            end
            div class: "card-body p-4" do
              div class: "alert alert-info mb-3" do
                i class: "ri ri-information-line me-2"
                strong "Rolling Summary"
                " - This summary gets constantly updated as the conversation evolves. It captures thread goals, key decisions, constraints, UX insights, and open items."
              end
              div class: "bg-light p-3 rounded border" do
                pre class: "mb-0 text-dark", style: "white-space: pre-wrap; font-family: 'Courier New', monospace; font-size: 13px; line-height: 1.6; margin: 0;" do
                  conversation.rolling_summary
                end
              end
              div class: "mt-3" do
                small class: "text-muted" do
                  "Character count: #{conversation.rolling_summary.length} | Word count: #{conversation.rolling_summary.split.size}"
                end
              end
              if conversation.last_summary_update_at
                div class: "mt-2" do
                  small class: "text-muted" do
                    "Last updated: #{conversation.last_summary_update_at.strftime('%b %d, %Y at %I:%M %p')}"
                  end
                end
              end
            end
          end
        else
          div class: "materio-card mb-4" do
            div class: "card-body p-4" do
              div class: "alert alert-info mb-0" do
                i class: "ri ri-information-line me-2"
                strong "Rolling Summary"
                " - This summary gets constantly updated as the conversation evolves. "
                "No rolling summary yet. Summary will be generated after #{10 - (conversation.message_count_since_summary || 0)} more messages or when a goal/constraint change is detected."
              end
            end
          end
        end

        # Messages Section
        div class: "materio-card" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-message-2-line me-2"
              "Messages (#{conversation.conversation_messages.count})"
            end
          end
          div class: "card-body p-4" do
            if conversation.conversation_messages.any?
              div class: "veritalk-admin-messages" do
                conversation.conversation_messages.order(position: :asc).each do |message|
                  div class: "veritalk-admin-message mb-3 p-3 rounded #{message.role}" do
                    div class: "d-flex justify-content-between align-items-start mb-2" do
                      span class: "badge bg-#{message.role == 'user' ? 'primary' : 'secondary'}" do
                        message.role.titleize
                      end
                      span class: "text-muted small" do
                        message.created_at.strftime("%I:%M %p, %b %d")
                      end
                    end
                    div class: "fw-semibold text-dark" do
                      simple_format(message.content)
                    end
                    div class: "text-muted small mt-2" do
                      "Position: #{message.position}"
                    end
                  end
                end
              end
            else
              p class: "text-muted" do "No messages in this conversation yet." end
            end
          end
        end

        # Summaries Section
        if conversation.conversation_summaries.any?
          div class: "materio-card mt-4" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-file-list-line me-2"
                "Summaries (#{conversation.conversation_summaries.count})"
              end
            end
            div class: "card-body p-4" do
              conversation.conversation_summaries.order(position: :asc).each do |summary|
                div class: "mb-3 p-3 bg-light rounded" do
                  div class: "d-flex justify-content-between align-items-start mb-2" do
                    span class: "badge bg-info" do
                      "Summary ##{summary.position}"
                    end
                    span class: "text-muted small" do
                      summary.created_at.strftime("%I:%M %p, %b %d")
                    end
                  end
                  div class: "fw-semibold text-dark" do
                    simple_format(summary.content)
                  end
                end
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
            h1 "Create Conversation", class: "mb-2 text-primary"
            para "Add new conversation", class: "text-muted mb-0"
          else
            h1 "Edit Conversation", class: "mb-2 text-primary"
            para "Update conversation information", class: "text-muted mb-0"
          end
        end
        div do
          link_to "Back to Conversations", admin_conversations_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5 class: "mb-0" do
          i class: "ri ri-chat-3-line me-2"
          "Conversation Information"
        end
      end
      div class: "card-body p-5" do
        f.inputs do
          f.input :user, as: :select, collection: User.all.map { |u| [u.email, u.id] }
          f.input :topic
          f.input :summary, as: :text, input_html: { rows: 4 }
          f.input :rolling_summary, as: :text,
                  input_html: {
                    rows: 15,
                    class: "form-control font-monospace",
                    style: "font-family: 'Courier New', monospace; font-size: 13px;"
                  },
                  hint: "Rolling conversation summary (auto-generated, but can be manually edited). Format: Thread goal, Key decisions, Constraints, UX/intent notes, Open items."
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
