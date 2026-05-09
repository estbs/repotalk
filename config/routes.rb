Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "repositories#index"

  resources :repositories, only: [:index, :new, :create, :show] do
    get :chat, to: "chats#stream", on: :member
  end
end
