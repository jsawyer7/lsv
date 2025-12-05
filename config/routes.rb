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

  # Onboarding routes
  patch 'onboarding', to: 'onboarding#update'

  resources :claims, only: [:new, :create, :show, :index, :edit, :update, :destroy]

  resources :claims do
    resources :challenges, only: [:create, :show]
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

  resources :theories, only: [:index, :new, :create, :edit, :update, :destroy] do
    collection do
      get :infinite
    end
  end

  get 'theories/public', to: 'theories#public_theories', as: :public_theories
  get 'theories/public_infinite', to: 'theories#public_infinite', as: :public_infinite_theories

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
  require 'sidekiq/web'
  require 'sidekiq/cron/web' if defined?(Sidekiq::Cron)
  
  # Protect Sidekiq web UI with basic auth in production
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(username),
        ::Digest::SHA256.hexdigest(ENV.fetch('SIDEKIQ_USERNAME', 'admin'))
      ) &
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(ENV.fetch('SIDEKIQ_PASSWORD', 'password'))
      )
    end
  end
  
  mount Sidekiq::Web => '/sidekiq'
end
