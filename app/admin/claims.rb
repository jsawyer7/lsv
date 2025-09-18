ActiveAdmin.register Claim do
  permit_params :content, :user_id

  # Custom page title
  menu label: "Claims", priority: 2

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Claims Management", class: "mb-2"
      para "Manage and review all claims submitted by users", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-4" do
            label "Content", class: "form-label"
            input type: "text", name: "q[content_cont]", placeholder: "Search content...", class: "form-control", value: params.dig(:q, :content_cont)
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
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterClaims()" do
            "Filter"
          end
          a href: admin_claims_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterClaims() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_claims_path}';

          var content = document.querySelector('input[name=\"q[content_cont]\"]').value;
          var userEmail = document.querySelector('input[name=\"q[user_email_cont]\"]').value;
          var dateFrom = document.querySelector('input[name=\"q[created_at_gteq]\"]').value;
          var dateTo = document.querySelector('input[name=\"q[created_at_lteq]\"]').value;

          if (content) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[content_cont]';
            input.value = content;
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
            th "Content"
            th "User"
            th "Email"
            th "Created At"
            th "Actions"
          end
        end
        tbody do
          claims.each do |claim|
            tr do
              td claim.id
              td truncate(claim.content, length: 50)
              # USER column with avatar and name
              td do
                if claim.user
                  div class: "d-flex align-items-center" do
                    div class: "avatar avatar-sm me-2" do
                      img src: asset_path("avatars/#{(claim.user.id % 20) + 1}.png"),
                          alt: claim.user.full_name || claim.user.email,
                          class: "rounded-circle"
                    end
                    div do
                      div class: "fw-semibold small" do
                        claim.user.full_name || claim.user.email.split('@').first.titleize
                      end
                      div class: "text-muted small" do
                        "@#{claim.user.email.split('@').first}"
                      end
                    end
                  end
                else
                  span class: "text-muted" do
                    "Unknown User"
                  end
                end
              end
              # EMAIL column
              td do
                if claim.user
                  span class: "text-body small" do
                    claim.user.email
                  end
                else
                  span class: "text-muted small" do
                    "N/A"
                  end
                end
              end
              td claim.created_at.strftime("%B %d, %Y")
              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_claim_path(claim)}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{admin_claim_path(claim)}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure you want to delete this claim?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :content
  filter :user
  filter :created_at
  filter :updated_at


  show do

    # Page Header
    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 "Claim ID ##{claim.id}", class: "mb-1 fw-bold text-dark"
        p "#{claim.created_at.strftime('%b %d, %Y, %I:%M %p')} (#{Time.zone.name})", class: "text-muted mb-0"
      end
      div class: "d-flex gap-2" do
        link_to "Edit Claim", edit_admin_claim_path(claim), class: "btn btn-primary px-3 py-2"
        link_to "Back to Claims", admin_claims_path, class: "btn btn-outline-secondary px-3 py-2"
      end
    end

    div class: "row g-4" do
      # Left Column - Claim Profile Card
      div class: "col-lg-4" do
        div class: "materio-card" do
          div class: "card-body p-4" do
            # Profile Section
            div class: "text-center mb-4" do
              div class: "materio-icon primary mb-3" do
                i class: "ri ri-file-text-line"
              end
              h3 "Claim ##{claim.id}", class: "mb-2 fw-bold"
              p "Claim ID ##{claim.id}", class: "text-muted mb-3"

              # Key Metrics
              div class: "row g-3 mb-4" do
                div class: "col-6" do
                  div class: "text-center" do
                    div class: "materio-icon success mb-2" do
                      i class: "ri ri-user-line"
                    end
                    div class: "fw-bold text-dark" do
                      if claim.user
                        claim.user.email.split('@').first
                      else
                        "Unknown"
                      end
                    end
                    div class: "text-muted small" do "Submitted By" end
                  end
                end
                div class: "col-6" do
                  div class: "text-center" do
                    div class: "materio-icon warning mb-2" do
                      i class: "ri ri-calendar-line"
                    end
                    div class: "fw-bold text-dark" do claim.created_at.strftime("%b %d") end
                    div class: "text-muted small" do "Created Date" end
                  end
                end
              end
            end

            # Details Section
            div class: "materio-info-item" do
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Username:" end
                span class: "fw-semibold" do
                  if claim.user
                    claim.user.email.split('@').first
                  else
                    "N/A"
                  end
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Email:" end
                span class: "fw-semibold" do
                  if claim.user
                    claim.user.email
                  else
                    "N/A"
                  end
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Status:" end
                span class: "badge bg-#{claim.state == 'verified' ? 'success' : claim.state == 'ai_validated' ? 'warning' : 'secondary'}" do
                  claim.state.present? ? claim.state.titleize : "Draft"
                end
              end
              div class: "d-flex justify-content-between align-items-center mb-2" do
                span class: "text-muted small fw-semibold" do "Contact:" end
                span class: "fw-semibold" do
                  if claim.user && claim.user.respond_to?(:phone)
                    claim.user.phone || "N/A"
                  else
                    "N/A"
                  end
                end
              end
              div class: "d-flex justify-content-between align-items-center" do
                span class: "text-muted small fw-semibold" do "Country:" end
                span class: "fw-semibold" do "USA" end
              end
            end

            # Action Button
            link_to "Edit Details", edit_admin_claim_path(claim), class: "btn btn-primary w-100 mt-3"
          end
        end
      end

      # Right Column - Information Cards
      div class: "col-lg-8" do
        div class: "row g-4" do
          # Claim Content Card
          div class: "col-12" do
            div class: "materio-card" do
              div class: "materio-header" do
                h5 class: "mb-0 fw-semibold" do
                  i class: "ri ri-file-text-line me-2"
                  "Claim Content"
                end
              end
              div class: "card-body p-4" do
                div class: "materio-content-area" do
                  if claim.content.present?
                    simple_format(claim.content, class: "mb-0 fw-semibold fs-5")
                  else
                    "No content available"
                  end
                end
              end
            end
          end

          # Information Cards Grid
          div class: "col-md-6" do
            div class: "materio-metric-card materio-metric-card-light" do
              div class: "materio-icon success" do
                i class: "ri ri-shield-check-line"
              end
              h6 "Validation Status", class: "mb-2 fw-semibold"
              div class: "badge bg-#{claim.state == 'verified' ? 'success' : claim.state == 'ai_validated' ? 'warning' : 'secondary'} mb-2" do
                claim.state.present? ? claim.state.titleize : "Draft"
              end
              p "Current validation status of this claim", class: "text-muted small mb-0"
            end
          end

          div class: "col-md-6" do
            div class: "materio-metric-card materio-metric-card-light" do
              div class: "materio-icon warning" do
                i class: "ri ri-brain-line"
              end
              h6 "AI Analysis", class: "mb-2 fw-semibold"
              div class: "fw-bold text-dark mb-2" do
                "#{claim.reasonings.count} Sources"
              end
              p "AI analysis from multiple sources", class: "text-muted small mb-0"
    end
  end

          div class: "col-md-6" do
            div class: "materio-metric-card materio-metric-card-light" do
              div class: "materio-icon info" do
                i class: "ri ri-calendar-line"
              end
              h6 "Created Date", class: "mb-2 fw-semibold"
              div class: "fw-bold text-dark mb-2" do
                claim.created_at.strftime("%B %d, %Y")
              end
              p "When this claim was first submitted", class: "text-muted small mb-0"
            end
          end

          div class: "col-md-6" do
            div class: "materio-metric-card materio-metric-card-light" do
              div class: "materio-icon primary" do
                i class: "ri ri-refresh-line"
              end
              h6 "Last Updated", class: "mb-2 fw-semibold"
              div class: "fw-bold text-dark mb-2" do
                claim.updated_at.strftime("%B %d, %Y")
              end
              p "Most recent modification date", class: "text-muted small mb-0"
            end
          end
        end
      end
    end

    # AI Analysis Section
    if claim.reasonings.any?
      div class: "row mt-4" do
        div class: "col-12" do
          div class: "materio-card" do
            div class: "materio-analysis-card" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-brain-line me-2"
                "AI Analysis & Reasoning"
              end
            end
            div class: "card-body p-4" do
      sources = claim.reasonings.order(:source)
        div id: "reasoning-sources-container" do
                div class: "reasoning-sources-list mb-4" do
            sources.each_with_index do |reasoning, idx|
              active = idx == 0
              span reasoning.source,
                      class: "materio-tab#{' active' if active}",
                data: { source: reasoning.source }
            end
          end
          sources.each_with_index do |reasoning, idx|
            div id: "reasoning-details-#{reasoning.source}",
                class: "reasoning-details-section",
                      style: "display:#{idx == 0 ? 'block' : 'none'};" do
                    div class: "materio-content-area" do
                      div class: "row g-3" do
                        div class: "col-md-6" do
                          div class: "materio-info-item" do
                            div class: "text-muted small fw-semibold mb-2" do
                              i class: "ri ri-checkbox-circle-line me-2"
                              "Result"
                            end
                            div class: "fw-semibold" do
                              span class: "badge bg-#{reasoning.result == 'valid' ? 'success' : reasoning.result == 'invalid' ? 'danger' : 'warning'}" do
                                reasoning.result.titleize
                              end
                            end
                          end
                        end
                        div class: "col-md-6" do
                          div class: "materio-info-item" do
                            div class: "text-muted small fw-semibold mb-2" do
                              i class: "ri ri-brain-line me-2"
                              "Source"
                            end
                            div class: "fw-semibold text-dark" do reasoning.source.titleize end
                          end
                        end
                        div class: "col-12" do
                          div class: "materio-info-item" do
                            div class: "text-muted small fw-semibold mb-2" do
                              i class: "ri ri-file-text-line me-2"
                              "AI Reasoning"
                            end
                            div class: "fw-semibold text-dark" do simple_format(reasoning.response) end
                          end
                        end
                      end
              end
            end
          end
        end
        script do
          raw <<-JS
            document.addEventListener('DOMContentLoaded', function() {
                    var tabs = document.querySelectorAll('.materio-tab');
              tabs.forEach(function(tab) {
                tab.addEventListener('click', function() {
                  tabs.forEach(function(t) {
                    t.classList.remove('active');
                  });
                  tab.classList.add('active');
                  var allDetails = document.querySelectorAll('.reasoning-details-section');
                  allDetails.forEach(function(d) { d.style.display = 'none'; });
                  var details = document.getElementById('reasoning-details-' + tab.dataset.source);
                  if (details) details.style.display = 'block';
                });
              });
            });
          JS
        end
            end
          end
        end
      end
    end

  end
end
