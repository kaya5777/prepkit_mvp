Rails.application.routes.draw do
  resources :histories, only: [ :index, :show, :new, :edit, :create, :update, :destroy ] do
    resources :question_answers, only: [ :index, :new, :create, :show, :destroy ]
  end
  root "preparations#new"
  resources :preparations, only: [ :new, :create ]
end
