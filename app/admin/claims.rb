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
              td do
                div class: "d-flex gap-2" do
                  link_to "View", admin_claim_path(claim), class: "btn btn-sm btn-outline-primary"
                  link_to "Edit", edit_admin_claim_path(claim), class: "btn btn-sm btn-outline-secondary"
                  link_to "Delete", admin_claim_path(claim), method: :delete,
                          data: { confirm: "Are you sure you want to delete this claim?" },
                          class: "btn btn-sm btn-outline-danger"
                end
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

  form do |f|
    div class: "page-header mb-4" do
      h1 "Edit Claim", class: "mb-2"
      para "Update claim information", class: "text-muted"
    end

    div class: "card" do
      div class: "card-body" do
    f.inputs do
          f.input :user, class: "form-control"
          f.input :content, class: "form-control"
        end
        f.actions do
          f.action :submit, label: "Update Claim", class: "btn btn-primary"
          f.action :cancel, label: "Cancel", class: "btn btn-secondary"
        end
      end
    end
  end

  show do
    div class: "page-header mb-4" do
      h1 "Claim Details", class: "mb-2"
      para "View detailed information about this claim", class: "text-muted"
    end

    div class: "card" do
      div class: "card-body" do
    attributes_table do
      row :id
      row :content
      row :user
      row :created_at
      row :updated_at
        end
      end
    end

    panel "Sources with Reasonings" do
      sources = claim.reasonings.order(:source)
      if sources.any?
        div id: "reasoning-sources-container" do
          div class: "reasoning-sources-list", style: "display: flex; gap: 1rem; margin-bottom: 1rem;" do
            sources.each_with_index do |reasoning, idx|
              active = idx == 0
              span reasoning.source,
                class: "reasoning-source-tab#{' active' if active}",
                style: "cursor:pointer; padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; border: 1px solid #e0e0e0; background: #{active ? '#2563eb' : '#f5f5'}; color: #{active ? '#fff' : '#222'};",
                data: { source: reasoning.source }
            end
          end
          sources.each_with_index do |reasoning, idx|
            div id: "reasoning-details-#{reasoning.source}",
                class: "reasoning-details-section",
                style: "display:#{idx == 0 ? 'block' : 'none'}; background: #fafbfc; border: 1px solid #e0e0e0; border-radius: 8px; padding: 1rem; margin-bottom: 1rem;" do
              h4 "#{reasoning.source} Details"
              div do
                b "Result: "
                span reasoning.result
              end
              div do
                b "Reasoning: "
                span simple_format(reasoning.response)
              end
            end
          end
        end
        script do
          raw <<-JS
            document.addEventListener('DOMContentLoaded', function() {
              var tabs = document.querySelectorAll('.reasoning-source-tab');
              tabs.forEach(function(tab) {
                tab.addEventListener('click', function() {
                  tabs.forEach(function(t) {
                    t.classList.remove('active');
                    t.style.background = '#f5f5f5';
                    t.style.color = '#222';
                  });
                  tab.classList.add('active');
                  tab.style.background = '#2563eb';
                  tab.style.color = '#fff';
                  var allDetails = document.querySelectorAll('.reasoning-details-section');
                  allDetails.forEach(function(d) { d.style.display = 'none'; });
                  var details = document.getElementById('reasoning-details-' + tab.dataset.source);
                  if (details) details.style.display = 'block';
                });
              });
            });
          JS
        end
      else
        span "No sources with reasonings found."
      end
    end
  end
end
