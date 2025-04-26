Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    passwords: 'devise/passwords'
  }

  devise_scope :user do  
    get '/users/sign_out' => 'devise/sessions#destroy'     
  end

  root to: "home#index"
  get 'dashboard', to: 'dashboard#index'
  resources :claims, only: [:new, :create, :show, :index]
end
