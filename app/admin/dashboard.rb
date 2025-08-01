# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do

    # Users section with claims button
    div class: 'panel' do
      h3 'Users'
      div class: 'panel_contents' do
        table_for User.order(created_at: :desc).limit(10) do
          column :id
          column :full_name
          column :email
          column :role
          column :created_at
          column 'Claims' do |user|
            link_to 'View Claims', admin_user_path(user),
                    target: '_blank',
                    class: 'button',
                    style: 'background-color: #007bff; color: white; padding: 5px 10px; ' \
                           'text-decoration: none; border-radius: 3px;'
          end
        end
        div style: 'margin-top: 10px;' do
          link_to 'View All Users', admin_users_path, class: 'button'
        end
      end
    end

    # Claims section
    div class: 'panel' do
      h3 'Recent Claims'
      div class: 'panel_contents' do
        table_for Claim.includes(:user).order(created_at: :desc).limit(15) do
          column :id
          column :user do |claim|
            link_to claim.user.full_name, admin_user_path(claim.user), target: '_blank'
          end
          column :content do |claim|
            div style: 'max-width: 300px; overflow: hidden; text-overflow: ellipsis; ' \
                       'white-space: nowrap;' do
              claim.content.truncate(100)
            end
          end
          column :state do |claim|
            background_color = case claim.state
                               when 'verified'
                                 '#28a745'
                               when 'ai_validated'
                                 '#ffc107'
                               else
                                 '#6c757d'
                               end
            span claim.state,
                 style: 'padding: 3px 8px; border-radius: 12px; font-size: 0.8rem; ' \
                        "font-weight: bold; background-color: #{background_color}; color: white;"
          end
          column :fact do |claim|
            claim.fact ? '✓' : '✗'
          end
          column :published do |claim|
            claim.published ? '✓' : '✗'
          end
          column :created_at
          column 'Actions' do |claim|
            div style: 'display: flex; gap: 5px;' do
              link_to 'View', admin_claim_path(claim),
                      target: '_blank',
                      class: 'button',
                      style: 'background-color: #007bff; color: white; padding: 3px 8px; ' \
                             'text-decoration: none; border-radius: 3px; font-size: 0.8rem;'
              link_to 'Edit', edit_admin_claim_path(claim),
                      target: '_blank',
                      class: 'button',
                      style: 'background-color: #28a745; color: white; padding: 3px 8px; ' \
                             'text-decoration: none; border-radius: 3px; font-size: 0.8rem;'
            end
          end
        end
        div style: 'margin-top: 10px;' do
          link_to 'View All Claims', admin_claims_path, class: 'button'
        end
      end
    end

    # Claims Statistics
    div class: 'panel' do
      h3 'Claims Statistics'
      div class: 'panel_contents' do
        div style: 'display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); ' \
                   'gap: 1rem;' do
          div style: 'background: #f8f9fa; padding: 1rem; border-radius: 8px; text-align: center;' do
            h4 style: 'margin: 0; color: #007bff;' do
              Claim.count
            end
            para style: 'margin: 5px 0 0 0; color: #6c757d;' do
              'Total Claims'
            end
          end
          div style: 'background: #f8f9fa; padding: 1rem; border-radius: 8px; text-align: center;' do
            h4 style: 'margin: 0; color: #28a745;' do
              Claim.verified.count
            end
            para style: 'margin: 5px 0 0 0; color: #6c757d;' do
              'Verified Claims'
            end
          end
          div style: 'background: #f8f9fa; padding: 1rem; border-radius: 8px; text-align: center;' do
            h4 style: 'margin: 0; color: #ffc107;' do
              Claim.ai_validated.count
            end
            para style: 'margin: 5px 0 0 0; color: #6c757d;' do
              'AI Validated'
            end
          end
          div style: 'background: #f8f9fa; padding: 1rem; border-radius: 8px; text-align: center;' do
            h4 style: 'margin: 0; color: #6c757d;' do
              Claim.drafts.count
            end
            para style: 'margin: 5px 0 0 0; color: #6c757d;' do
              'Draft Claims'
            end
          end
          div style: 'background: #f8f9fa; padding: 1rem; border-radius: 8px; text-align: center;' do
            h4 style: 'margin: 0; color: #dc3545;' do
              Claim.facts.count
            end
            para style: 'margin: 5px 0 0 0; color: #6c757d;' do
              'Fact Claims'
            end
          end
          div style: 'background: #f8f9fa; padding: 1rem; border-radius: 8px; text-align: center;' do
            h4 style: 'margin: 0; color: #17a2b8;' do
              Claim.published_facts.count
            end
            para style: 'margin: 5px 0 0 0; color: #6c757d;' do
              'Published Facts'
            end
          end
        end
      end
    end
  end
end
