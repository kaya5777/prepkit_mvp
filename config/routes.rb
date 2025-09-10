Rails.application.routes.draw do
  root "preparations#new"
  resources :preparations, only: [:new, :create]
end