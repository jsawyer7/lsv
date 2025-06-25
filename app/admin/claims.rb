ActiveAdmin.register Claim do
  permit_params :content, :evidence, :user_id

  index do
    selectable_column
    id_column
    column :content
    column :evidence
    column :user
    column :created_at
    actions
  end

  filter :content
  filter :evidence
  filter :user
  filter :created_at

  form do |f|
    f.inputs do
      f.input :user
      f.input :content
      f.input :evidence
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :content
      row :evidence
      row :user
      row :created_at
      row :updated_at
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
                style: "cursor:pointer; padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; border: 1px solid #e0e0e0; background: #{active ? '#2563eb' : '#f5f5f5'}; color: #{active ? '#fff' : '#222'};",
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