Rails.application.routes.draw do
  root to: "home#index"

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'devise/sessions',
    passwords: 'devise/passwords',
    confirmations: 'users/confirmations'
  }

  devise_scope :user do  
    get '/users/sign_out' => 'devise/sessions#destroy'     
  end

  get 'dashboard', to: 'dashboard#index'
  resources :claims, only: [:new, :create, :show, :index]
end
