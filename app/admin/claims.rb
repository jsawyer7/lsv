ActiveAdmin.register Claim do
  permit_params :content, :user_id

  index do
    selectable_column
    id_column
    column :content
    column :user
    column :state
    column :created_at
    actions
  end

  filter :content
  filter :user
  filter :state
  filter :created_at

  form do |f|
    f.inputs do
      f.input :user
      f.input :content
      f.input :state, as: :select, collection: Claim.states.keys
    end
    f.actions
  end

  show do
    # Main claim information
    attributes_table do
      row :id
      row :content
      row :user
      row :state
      row :fact
      row :published
      row :created_at
      row :updated_at
    end

    # Evidences Section
    panel "Evidences" do
      evidences = claim.evidences.includes(:challenges)
      if evidences.any?
        evidences.each_with_index do |evidence, index|
          div class: "evidence-section", style: "margin-bottom: 2rem; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;" do
            # Evidence Header
            div class: "evidence-header", 
                style: "background: #f8f9fa; padding: 1rem; border-bottom: 1px solid #e0e0e0; cursor: pointer;",
                onclick: "toggleEvidence(#{evidence.id})" do
              h4 style: "margin: 0; display: flex; justify-content: space-between; align-items: center;" do
                span "Evidence ##{evidence.id}"
                span "▼", id: "evidence-toggle-#{evidence.id}", style: "font-size: 1.2rem;"
              end
            end
            
            # Evidence Content (collapsible)
            div id: "evidence-content-#{evidence.id}", 
                class: "evidence-content",
                style: "display: none; padding: 1rem;" do
              
              # Evidence Details
              div style: "margin-bottom: 1rem;" do
                h5 "Evidence Details"
                attributes_table_for evidence do
                  row :id
                  row :sources do |ev|
                    ev.sources.map { |s| ev.class.sources.key(s) }.join(", ")
                  end
                  row :created_at
                  row :updated_at
                end
              end
              
              # Evidence Challenges
              div style: "margin-bottom: 1rem;" do
                h5 "Challenges"
                challenges = evidence.challenges.includes(:user, :reasonings)
                if challenges.any?
                  table_for challenges do
                    column :id
                    column :user
                    column :text
                    column :status
                    column :created_at
                    column "Actions" do |challenge|
                      link_to "View Details", "#", 
                              onclick: "toggleChallenge(#{challenge.id}); return false;",
                              class: "button",
                              style: "background-color: #007bff; color: white; padding: 3px 8px; text-decoration: none; border-radius: 3px; font-size: 0.8rem;"
                    end
                  end
                  
                  # Challenge Details (hidden by default)
                  challenges.each do |challenge|
                    div id: "challenge-details-#{challenge.id}", 
                        class: "challenge-details",
                        style: "display: none; background: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 6px; padding: 1rem; margin-top: 1rem;" do
                      h6 "Challenge ##{challenge.id} Details"
                      attributes_table_for challenge do
                        row :id
                        row :user
                        row :text
                        row :status
                        row :created_at
                        row :updated_at
                      end
                      
                      # Challenge Reasonings
                      reasonings = challenge.reasonings.order(:source)
                      if reasonings.any?
                        div style: "margin-top: 1rem;" do
                          h6 "Challenge Reasonings"
                          reasonings.each do |reasoning|
                            div style: "background: white; border: 1px solid #e0e0e0; border-radius: 4px; padding: 0.8rem; margin-bottom: 0.5rem;" do
                              div style: "font-weight: bold; color: #2563eb; margin-bottom: 0.5rem;" do
                                reasoning.source
                              end
                              div style: "margin-bottom: 0.5rem;" do
                                b "Result: "
                                span reasoning.result
                              end
                              div do
                                b "Response: "
                                div style: "margin-top: 0.5rem; white-space: pre-wrap;" do
                                  reasoning.response
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                else
                  para "No challenges for this evidence."
                end
              end
            end
          end
        end
      else
        para "No evidences found for this claim."
      end
    end

    # Claim Challenges Section
    panel "Claim Challenges" do
      challenges = claim.challenges.includes(:user, :reasonings)
      if challenges.any?
        challenges.each do |challenge|
          div class: "challenge-section", style: "margin-bottom: 1.5rem; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;" do
            # Challenge Header
            div class: "challenge-header", 
                style: "background: #f8f9fa; padding: 1rem; border-bottom: 1px solid #e0e0e0; cursor: pointer;",
                onclick: "toggleClaimChallenge(#{challenge.id})" do
              h4 style: "margin: 0; display: flex; justify-content: space-between; align-items: center;" do
                span "Challenge ##{challenge.id} - #{challenge.user.full_name}"
                span "▼", id: "claim-challenge-toggle-#{challenge.id}", style: "font-size: 1.2rem;"
              end
            end
            
            # Challenge Content (collapsible)
            div id: "claim-challenge-content-#{challenge.id}", 
                class: "claim-challenge-content",
                style: "display: none; padding: 1rem;" do
              
              # Challenge Details
              div style: "margin-bottom: 1rem;" do
                h5 "Challenge Details"
                attributes_table_for challenge do
                  row :id
                  row :user
                  row :text
                  row :status
                  row :created_at
                  row :updated_at
                end
              end
              
              # Challenge Reasonings
              reasonings = challenge.reasonings.order(:source)
              if reasonings.any?
                div style: "margin-top: 1rem;" do
                  h5 "Challenge Reasonings"
                  reasonings.each do |reasoning|
                    div style: "background: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 4px; padding: 0.8rem; margin-bottom: 0.5rem;" do
                      div style: "font-weight: bold; color: #2563eb; margin-bottom: 0.5rem;" do
                        reasoning.source
                      end
                      div style: "margin-bottom: 0.5rem;" do
                        b "Result: "
                        span reasoning.result
                      end
                      div do
                        b "Response: "
                        div style: "margin-top: 0.5rem; white-space: pre-wrap;" do
                          reasoning.response
                        end
                      end
                    end
                  end
                end
              else
                para "No reasonings for this challenge."
              end
            end
          end
        end
      else
        para "No challenges found for this claim."
      end
    end

    # Claim Reasonings Section (existing functionality)
    panel "Claim Reasonings" do
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

    # JavaScript for expandable sections
    script do
      raw <<-JS
        function toggleEvidence(evidenceId) {
          var content = document.getElementById('evidence-content-' + evidenceId);
          var toggle = document.getElementById('evidence-toggle-' + evidenceId);
          if (content.style.display === 'none') {
            content.style.display = 'block';
            toggle.textContent = '▲';
          } else {
            content.style.display = 'none';
            toggle.textContent = '▼';
          }
        }

        function toggleChallenge(challengeId) {
          var content = document.getElementById('challenge-details-' + challengeId);
          if (content.style.display === 'none') {
            content.style.display = 'block';
          } else {
            content.style.display = 'none';
          }
        }

        function toggleClaimChallenge(challengeId) {
          var content = document.getElementById('claim-challenge-content-' + challengeId);
          var toggle = document.getElementById('claim-challenge-toggle-' + challengeId);
          if (content.style.display === 'none') {
            content.style.display = 'block';
            toggle.textContent = '▲';
          } else {
            content.style.display = 'none';
            toggle.textContent = '▼';
          }
        }
      JS
    end
  end
end