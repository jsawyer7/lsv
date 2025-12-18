Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  root to: "home#index"

  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    confirmations: 'users/confirmations',
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  devise_scope :user do
    get '/users/sign_out' => 'devise/sessions#destroy'
  end

  get 'dashboard', to: 'dashboard#index'
  get 'veritalk', to: 'dashboard#veritalk', as: :veritalk

  # Onboarding routes
  patch 'onboarding', to: 'onboarding#update'

  # Terms and consent routes
  post 'accept_terms', to: 'users#accept_terms'

  resources :claims, only: [:new, :create, :show, :index, :edit, :update, :destroy]

  resources :claims do
    resources :challenges, only: [:create, :show]
    resources :likes, only: [:create, :destroy]
    resources :shares, only: [:create]
    resources :comments, only: [:create, :destroy] do
      resources :likes, only: [:create, :destroy]
      resources :shares, only: [:create]
    end
    post :validate_claim, on: :collection
    post :validate_evidence, on: :collection
    post :generate_ai_evidence, on: :collection
    member do
      get :reasoning_for_source
      post :publish_fact
      post :unpublish_fact
    end
  end

  post '/evidences/:evidence_id/challenges', to: 'challenges#create_for_evidence', as: :evidence_challenges

  resources :evidences, only: [] do
    resources :challenges, only: [:create]
  end

  post '/veritalk/chat', to: 'veritalk#chat'

  post '/ai/claim_suggestion', to: 'ai#claim_suggestion'
  post '/ai/evidence_suggestion', to: 'ai#evidence_suggestion'
  post '/ai/claim_guidance', to: 'ai#claim_guidance'
  get '/privacy', to: 'static#privacy', as: :privacy
  get '/ai-data', to: 'static#ai_data', as: :ai_data
  get '/terms', to: 'static#terms', as: :terms
  get 'lsv', to: 'static#lsv'
  get 'faq', to: 'static#faq'
  get '/mission', to: 'static#mission'
  get '/sources', to: 'static#sources'
  get 'feeds', to: 'feeds#index'
  get 'feeds/infinite', to: 'feeds#infinite'
  get 'shared', to: 'shares#index', as: :shared_feed
  get 'shared/infinite', to: 'shares#infinite', as: :shared_feed_infinite
  post 'shares/:id/reshare', to: 'shares#reshare', as: :reshare_share
  post 'claims/:claim_id/reshare', to: 'shares#reshare', as: :reshare_claim
  post 'theories/:theory_id/reshare', to: 'shares#reshare', as: :reshare_theory
  post 'claims/:claim_id/comments/:comment_id/reshare', to: 'shares#reshare', as: :reshare_claim_comment
  post 'theories/:theory_id/comments/:comment_id/reshare', to: 'shares#reshare', as: :reshare_theory_comment
  get 'contact', to: 'static#contact'
  post 'contact', to: 'static#send_contact_message'

  resources :peers, only: [:index] do
    collection do
      post :add
      post :accept
      delete :remove
    end
  end

  resources :follows, only: [:create, :destroy]

  get '/users/:id/profile', to: 'users#profile', as: :user_profile
  get '/users/:id/profile/infinite', to: 'users#profile_infinite', as: :user_profile_infinite

  # Specific theory routes must come before resources to avoid route conflicts
  get 'theories/public', to: 'theories#public_theories', as: :public_theories
  get 'theories/public_infinite', to: 'theories#public_infinite', as: :public_infinite_theories

  resources :theories, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    resources :likes, only: [:create, :destroy]
    resources :shares, only: [:create]
    resources :comments, only: [:create, :destroy] do
      resources :likes, only: [:create, :destroy]
      resources :shares, only: [:create]
    end
    collection do
      get :infinite
    end
  end

  resource :settings, only: [:edit, :update] do
    get :notifications, on: :collection
    get :subscription, on: :collection
    get :billing, on: :collection
    post :refresh_billing, on: :collection
    get 'plan/:id', to: 'settings#plan_details', as: :plan_details, on: :collection
    post 'plan/:id/cancel', to: 'settings#cancel_subscription', as: :cancel_subscription, on: :collection
    get 'invoice/:id/download', to: 'settings#download_invoice', as: :download_invoice, on: :collection
  end

  # Subscription routes
  resources :chargebee_subscriptions, only: [:create]

  # Entitlements routes
  resources :entitlements, only: [:index, :show]

  post '/webhooks/chargebee', to: 'webhooks#chargebee'
  get '/webhooks/health', to: 'webhooks#health_check'



  resources :facts, only: [:index] do
    collection do
      get :infinite
    end
  end

  # API routes for Text Content creation
  namespace :api do
    post '/text-content/create-next', to: 'text_contents#create_next'
    post '/text-content/ai-validate-structure', to: 'text_contents#ai_validate_structure'
  end

  # Sidekiq Web UI for monitoring background jobs
  # Note: Redis connection is configured in config/initializers/sidekiq.rb
  require 'sidekiq/web'
  require 'sidekiq/cron/web' if defined?(Sidekiq::Cron)

  # Protect Sidekiq web UI with basic auth in production
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      expected_username = ENV.fetch('SIDEKIQ_USERNAME', 'admin')
      expected_password = ENV.fetch('SIDEKIQ_PASSWORD', 'password')

      # Use secure_compare for constant-time comparison to prevent timing attacks
      username_match = ActiveSupport::SecurityUtils.secure_compare(
        username.to_s,
        expected_username
      )

      password_match = ActiveSupport::SecurityUtils.secure_compare(
        password.to_s,
        expected_password
      )

      # Return boolean result (both must match)
      username_match && password_match
    end
  end

  mount Sidekiq::Web => '/sidekiq'
end
