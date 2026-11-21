Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  resources :recipes, only: %i[index show] do
    get :results, on: :collection
    resources :cook_sessions, only: %i[create]
    resources :favorites, only: %i[create]
  end
  resources :favorites, only: %i[destroy]
  resources :cook_sessions, only:%i[destroy] do
    resources :instructions, only: %i[show]
    resources :messages, only: %i[create]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
