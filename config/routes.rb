Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  resource :other_sessions, only: :destroy

  get "forgot-password", to: "passwords#new", as: :new_password
  post "forgot-password", to: "passwords#create", as: :passwords
  get "reset-password/:token", to: "passwords#edit", as: :edit_password
  patch "reset-password/:token", to: "passwords#update", as: :password

  get "dashboard", to: "dashboard#show", as: :dashboard
  resources :markets, only: %i[ index show ]
  resources :signals, only: %i[ index show ]
  resources :strategies, only: %i[ index edit update ] do
    member do
      post :clone
      patch :archive
      patch :toggle
    end
  end
  resource :account, only: %i[ show create ]
  resources :ledger_entries, only: :create do
    resource :reversal, only: :create
  end
  resource :settings, only: :show
  resource :risk_profile, only: :update, path: "settings/risk"
  get "risk", to: redirect("/settings")

  root "pages#home"
end
