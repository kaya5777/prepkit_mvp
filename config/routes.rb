Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  resources :histories, only: [ :index, :show, :new, :edit, :create, :update, :destroy ] do
    collection do
      get :my_histories
      get :all_histories
    end
    resources :question_answers, only: [ :index, :new, :create, :show, :destroy ]
  end
  root "preparations#new"
  resources :preparations, only: [ :new, :create ]
end
