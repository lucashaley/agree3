Rails.application.routes.draw do
  get "/altcha", to: "altcha#new"
  get "contact_form", to: "contact#new"
  post "contact", to: "contact#create"
  get "about", to: "pages#about"
  # get  "sign_in", to: "sessions#new"
  # post "sign_in", to: "sessions#create"
  get  "sign_in", to: "sessions/passwordlesses#new"
  post "sign_in", to: "sessions/passwordlesses#create"
  get  "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resources :sessions, only: [ :index, :show, :destroy ]
  resource  :password, only: [ :edit, :update ]
  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end
  namespace :sessions do
    resource :passwordless, only: [ :new, :edit, :create ]
  end
  root "home#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  resources :statements do
    collection do
      get :search
      post :sync_agreements
    end
    member do
      post :agree
      post :create_variant
      post :flag
      delete :unflag
      get :svg
      get :png
      get :jpg
      get :og_image
    end
  end
end
