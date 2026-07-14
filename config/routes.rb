Rails.application.routes.draw do
  root "home#index"
  get "up" => "rails/health#show", as: :rails_health_check

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  post "/development/login", to: "sessions#development", as: :development_login if Rails.env.local?
  delete "/logout", to: "sessions#destroy", as: :logout

  resource :notification_address, only: %i[edit update]
  get "/notification-address/verify", to: "notification_addresses#verify", as: :verify_notification_address
  get "/notification-address/unsubscribe", to: "notification_addresses#unsubscribe", as: :unsubscribe_notification_address

  resources :listings, only: :create
  resources :searches, only: %i[create show]
  resources :subscriptions, only: %i[create update destroy]
  get "/subscriptions/:id/unsubscribe", to: "subscriptions#unsubscribe", as: :unsubscribe_subscription
  resource :account, only: :destroy

  get "/terms", to: "policies#terms", as: :terms
  get "/privacy", to: "policies#privacy", as: :privacy
  get "/admin", to: "admin#index", as: :admin
  patch "/admin/sites/:id", to: "admin#update_site", as: :admin_site
end
