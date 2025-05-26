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
  resources :claims, only: [:new, :create, :show, :index]

  resources :claims do
    resources :challenges, only: [:create, :show]
    post :validate_claim, on: :collection
  end

  get '/privacy', to: 'static#privacy', as: :privacy
  get '/ai-data', to: 'static#ai_data', as: :ai_data
  get '/terms', to: 'static#terms', as: :terms
end
