Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  
  root to: redirect('/feeds')

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
  resources :claims, only: [:new, :create, :show, :index, :edit, :update, :destroy]

  resources :claims do
    resources :challenges, only: [:create, :show]
    post :validate_claim, on: :collection
  end

  get '/privacy', to: 'static#privacy', as: :privacy
  get '/ai-data', to: 'static#ai_data', as: :ai_data
  get '/terms', to: 'static#terms', as: :terms
  get 'lsv', to: 'static#lsv'
  get 'faq', to: 'static#faq'
  get '/mission', to: 'static#mission'
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

  resource :settings, only: [:edit, :update] do
    get :notifications, on: :collection
  end
end
