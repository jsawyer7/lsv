ActiveAdmin.register GrokBotConnection do
  permit_params :name, :description, :enabled, scopes: []

  menu false
  actions :all
  config.filters = false
  config.sort_order = 'created_at_desc'

  controller do
    layout "active_admin_custom"

    # build_resource runs the Pundit check (GrokBotConnectionPolicy#create?).
    def create
      build_resource
      resource.created_by = current_user
      if resource.save
        show_token(resource)
      else
        render :new
      end
    end

    private

    # The token exists only in this response; LSV stores just its digest.
    def show_token(connection)
      @connection = connection
      @plain_token = connection.plain_token
      response.headers['Cache-Control'] = 'no-store'
      render 'admin/grok_bot_connections/token', layout: "active_admin_custom"
    end
  end

  member_action :regenerate_token, method: :post do
    resource.regenerate_token!
    show_token(resource)
  end

  member_action :toggle, method: :post do
    resource.update!(enabled: !resource.enabled)
    redirect_to admin_grok_bot_connection_path(resource),
                notice: resource.enabled ? "Connection enabled." : "Connection disabled. Its token is rejected until you enable it again."
  end

  index do
    div class: "page-header mb-4" do
      div class: "d-flex flex-wrap justify-content-between align-items-start gap-3" do
        div do
          h1 "Grok Bot Connections", class: "mb-2"
          para "Give a Grok Bot read-only access to LSV data through a custom MCP connector.", class: "text-muted mb-0"
        end
        div do
          link_to "New Connection", new_admin_grok_bot_connection_path, class: "btn btn-primary"
        end
      end
    end

    div class: "alert alert-info mb-4" do
      div class: "d-flex align-items-start" do
        i class: "ri ri-plug-line me-2", style: "font-size: 20px;"
        div do
          strong "MCP server URL: "
          code mcp_url
          div class: "small mt-1" do
            text_node "Create a connection, copy its token, and add LSV as a custom MCP connector in Grok Bot with this URL and the token header."
          end
        end
      end
    end

    calls_24h = GrokBotToolCall.where(created_at: 24.hours.ago..).group(:grok_bot_connection_id).count

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "Name"
            th "Status"
            th "Data access"
            th "Token"
            th "Last used"
            th "Calls (24h)"
            th "Actions"
          end
        end
        tbody do
          if grok_bot_connections.empty?
            tr do
              td colspan: 7, class: "text-center text-muted py-4" do
                text_node "No connections yet. "
                a "Create one", href: new_admin_grok_bot_connection_path
                text_node " to let a Grok Bot read LSV."
              end
            end
          end
          grok_bot_connections.each do |connection|
            tr do
              td do
                div connection.name, class: "fw-semibold"
                div truncate(connection.description, length: 60), class: "text-muted small mt-1" if connection.description.present?
              end
              td do
                span(connection.enabled ? "Enabled" : "Disabled", class: "badge bg-#{connection.enabled ? 'success' : 'secondary'}")
              end
              td do
                if connection.scopes.empty?
                  span "None", class: "text-muted"
                else
                  connection.scopes.each { |s| span s.titleize, class: "badge bg-label-primary me-1" }
                end
              end
              td { code "#{connection.token_prefix}…" }
              td connection.last_used_at ? "#{time_ago_in_words(connection.last_used_at)} ago" : "Never"
              td calls_24h.fetch(connection.id, 0)
              td do
                div class: "d-flex gap-2" do
                  a "View", href: admin_grok_bot_connection_path(connection), class: "btn btn-sm btn-outline-primary"
                  a "Edit", href: edit_admin_grok_bot_connection_path(connection), class: "btn btn-sm btn-outline-info"
                  a "Delete", href: admin_grok_bot_connection_path(connection), class: "btn btn-sm btn-outline-danger",
                              "data-method": "delete", "data-confirm": "Delete this connection? Grok Bot loses access immediately."
                end
              end
            end
          end
        end
      end
    end
  end

  show do
    connection = grok_bot_connection
    tools = LsvMcp::Server.tools_for(connection)
    calls = connection.tool_calls.recent.limit(50).to_a

    div class: "d-flex flex-wrap justify-content-between align-items-center gap-3 mb-4" do
      div do
        h1 connection.name, class: "mb-1 fw-bold text-dark"
        para "Created #{connection.created_at.strftime('%b %d, %Y, %I:%M %p')}#{" by #{connection.created_by.email}" if connection.created_by}", class: "text-muted mb-0"
      end
      div class: "d-flex flex-wrap gap-2" do
        link_to(connection.enabled ? "Disable" : "Enable", toggle_admin_grok_bot_connection_path(connection),
                method: :post, class: "btn btn-#{connection.enabled ? 'outline-warning' : 'success'} px-3 py-2",
                data: { confirm: connection.enabled ? "Grok Bot will lose access until you enable this connection again. Continue?" : nil })
        link_to "Regenerate Token", regenerate_token_admin_grok_bot_connection_path(connection),
                method: :post, class: "btn btn-outline-danger px-3 py-2",
                data: { confirm: "The current token stops working immediately and you must paste the new one into Grok Bot. Continue?" }
        link_to "Edit", edit_admin_grok_bot_connection_path(connection), class: "btn btn-outline-primary px-3 py-2"
        link_to "Back", admin_grok_bot_connections_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-5" do
        div class: "materio-card mb-4" do
          div class: "materio-header" do
            h5(class: "mb-0 fw-semibold") { i(class: "ri ri-plug-line me-2"); text_node "Connector settings for Grok Bot" }
          end
          div class: "card-body p-4" do
            div class: "mb-3" do
              div "MCP server URL", class: "text-muted small fw-semibold mb-1"
              code mcp_url
            end
            div class: "mb-3" do
              div "Header", class: "text-muted small fw-semibold mb-1"
              code "X-LSV-Token: #{connection.token_prefix}…"
              div class: "small text-muted mt-1" do
                text_node "or "
                code "Authorization: Bearer #{connection.token_prefix}…"
              end
            end
            div class: "small text-muted" do
              text_node "The full token was shown once when it was created. If it is lost, regenerate it and update Grok Bot."
            end
          end
        end

        div class: "materio-card" do
          div class: "card-body p-4" do
            div class: "mb-3" do
              span(connection.enabled ? "Enabled" : "Disabled", class: "badge bg-#{connection.enabled ? 'success' : 'secondary'}")
            end
            [
              ["Token", "#{connection.token_prefix}…"],
              ["Token issued", connection.token_generated_at.strftime("%b %d, %Y %I:%M %p")],
              ["Last used", connection.last_used_at ? "#{connection.last_used_at.strftime('%b %d, %Y %I:%M %p')} (#{time_ago_in_words(connection.last_used_at)} ago)" : "Never"],
              ["Last IP", connection.last_used_ip || "—"]
            ].each do |label, value|
              div class: "d-flex justify-content-between align-items-center mb-2 gap-3" do
                span "#{label}:", class: "text-muted small fw-semibold"
                span value, class: "fw-semibold text-end"
              end
            end
            if connection.description.present?
              div class: "mt-3 pt-3 border-top" do
                div "Description:", class: "text-muted small fw-semibold mb-2"
                div simple_format(connection.description)
              end
            end
          end
        end
      end

      div class: "col-lg-7" do
        div class: "materio-card mb-4" do
          div class: "materio-header" do
            h5(class: "mb-0 fw-semibold") { i(class: "ri ri-database-2-line me-2"); text_node "Data this Bot can read" }
          end
          div class: "card-body p-4" do
            GrokBotConnection::SCOPES.each do |scope, label|
              allowed = connection.scope?(scope)
              div class: "d-flex align-items-start mb-2" do
                i class: "ri #{allowed ? 'ri-checkbox-circle-fill text-success' : 'ri-close-circle-line text-muted'} me-2"
                div do
                  strong scope.titleize, class: allowed ? nil : "text-muted"
                  div label, class: "small text-muted"
                end
              end
            end
            div class: "mt-3 pt-3 border-top small" do
              strong "Tools exposed (#{tools.size}): "
              if tools.empty?
                span "none — enable at least one data group.", class: "text-danger"
              else
                tools.each { |t| code t.tool_name, class: "me-1" }
              end
            end
          end
        end

        div class: "materio-card" do
          div class: "materio-header" do
            h5(class: "mb-0 fw-semibold") { i(class: "ri ri-history-line me-2"); text_node "Recent tool calls" }
          end
          div class: "card-body p-0" do
            if calls.empty?
              para "No calls yet. Once Grok Bot uses this connection, each request appears here.", class: "text-muted p-4 mb-0"
            else
              div class: "table-responsive" do
                table class: "table table-sm mb-0" do
                  thead do
                    tr do
                      th "Time"
                      th "Tool"
                      th "Arguments"
                      th "Result"
                      th "ms"
                    end
                  end
                  tbody do
                    calls.each do |call|
                      tr do
                        td call.created_at.strftime("%b %d %H:%M:%S"), class: "text-nowrap small"
                        td { code call.tool_name }
                        td truncate(call.arguments.to_json, length: 80), class: "small text-break"
                        td do
                          if call.status == 'ok'
                            span "#{call.result_count || 0} result#{'s' unless call.result_count == 1}", class: "badge bg-label-success"
                          else
                            span "Error", class: "badge bg-label-danger", title: call.error_message
                            div truncate(call.error_message.to_s, length: 80), class: "small text-muted"
                          end
                        end
                        td call.duration_ms, class: "small"
                      end
                    end
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
          h1(f.object.new_record? ? "New Grok Bot Connection" : "Edit Grok Bot Connection", class: "mb-2 text-primary")
          para(f.object.new_record? ? "A token is generated when you save. It is shown once." : "Changes apply to the Bot's next request.", class: "text-muted mb-0")
        end
        div do
          link_to "Back to Connections", admin_grok_bot_connections_path, class: "btn btn-outline-secondary"
        end
      end
    end

    div class: "card" do
      div class: "card-header bg-primary text-white" do
        h5(class: "mb-0") { i(class: "ri ri-robot-2-line me-2"); text_node "Connection" }
      end
      div class: "card-body p-5" do
        f.semantic_errors
        f.inputs do
          f.input :name, hint: "e.g. the Bot's name in Grok Bot", input_html: { class: "form-control" }
          f.input :description, as: :text, input_html: { rows: 3, class: "form-control" }
          f.input :scopes, as: :check_boxes, label: "Data the Bot can read",
                           collection: GrokBotConnection::SCOPES.map { |key, label| ["#{key.titleize} — #{label}", key] }
          f.input :enabled, as: :boolean, label: "Enabled (the token works)"
        end

        div class: "mt-4 pt-4 border-top" do
          div class: "d-flex justify-content-end gap-3" do
            f.action :submit, label: (f.object.new_record? ? "Create and show token" : "Save"), button_html: { class: "materio-btn-primary" }
            f.action :cancel, label: "Cancel", wrapper_html: { class: "materio-btn-secondary" }
          end
        end
      end
    end
  end
end
