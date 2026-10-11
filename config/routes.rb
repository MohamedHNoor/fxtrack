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

  root "pages#home"
end
