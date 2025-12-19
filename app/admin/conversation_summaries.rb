ActiveAdmin.register ConversationSummary do
  permit_params :conversation_id, :content, :position

  menu label: "VeriTalk Summaries", priority: 6, parent: "VeriTalk Conversations"

  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "VeriTalk Summaries", class: "mb-2"
      para "View all conversation summaries", class: "text-muted"
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "ID"
            th "Conversation"
            th "Content"
            th "Position"
            th "Created At"
            th "Actions"
          end
        end
        tbody do
          conversation_summaries.each do |summary|
            tr do
              td summary.id
              td do
                link_to "Conversation ##{summary.conversation_id}", admin_conversation_path(summary.conversation), class: "text-primary"
              end
              td do
                div class: "fw-semibold" do
                  truncate(summary.content, length: 80)
                end
              end
              td summary.position
              td summary.created_at.strftime("%B %d, %Y %I:%M %p")
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_conversation_summary_path(summary)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{admin_conversation_summary_path(summary)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :conversation
  filter :position
  filter :created_at

  show do
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Summary ##{conversation_summary.id}", class: "mb-1 fw-bold text-dark"
        p "#{conversation_summary.created_at.strftime('%b %d, %Y, %I:%M %p')}", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Summary", edit_admin_conversation_summary_path(conversation_summary), class: "btn btn-primary px-3 py-2"
        link_to "Back to Summaries", admin_conversation_summaries_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-8" do
        div class: "materio-card" do
          div class: "card-body p-4" do
            div class: "mb-4" do
              div class: "d-flex justify-content-between align-items-center mb-3" do
                span class: "badge bg-info fs-6" do
                  "Summary ##{conversation_summary.position}"
                end
                span class: "text-muted" do
                  conversation_summary.created_at.strftime("%I:%M %p, %b %d")
                end
              end

              div class: "materio-content-area" do
                div class: "fw-semibold fs-5 text-dark" do
                  simple_format(conversation_summary.content)
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
                    link_to "Conversation ##{conversation_summary.conversation_id}", admin_conversation_path(conversation_summary.conversation), class: "text-primary"
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
                    conversation_summary.created_at.strftime("%B %d, %Y at %I:%M %p")
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
                span class: "text-muted small fw-semibold" do "Summary ID:" end
                span class: "fw-semibold" do conversation_summary.id end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Position:" end
                span class: "fw-semibold" do conversation_summary.position end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Content Length:" end
                span class: "fw-semibold" do "#{conversation_summary.content.length} characters" end
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
            h1 "Create Summary", class: "mb-2 text-primary"
          else
            h1 "Edit Summary", class: "mb-2 text-primary"
          end
        end
        div do
          link_to "Back to Summaries", admin_conversation_summaries_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-body p-5" do
        f.inputs do
          f.input :conversation, as: :select, collection: Conversation.all.map { |c| ["##{c.id} - #{truncate(c.topic, length: 40)}", c.id] }
          f.input :content, as: :text, input_html: { rows: 6 }
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
