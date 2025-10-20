Rails.application.routes.draw do
  resources :histories, only: [:show, :new, :edit, :create, :update]
  root "preparations#new"
  resources :preparations, only: [:new, :create]
end