Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  resources :histories, only: [ :index, :show, :new, :edit, :create, :update, :destroy ] do
    collection do
      get :my_histories
      get :all_histories
    end
    member do
      post :analyze_match
    end
    resources :question_answers, only: [ :index, :new, :create, :show, :destroy ]
  end
  root "preparations#new"
  resources :preparations, only: [ :new, :create ]
  resources :resumes, only: [ :index, :show, :new, :create, :destroy ] do
    member do
      get :download
    end
  end

  # 設定画面
  resource :settings, only: [ :show, :update ] do
    delete :destroy_account, on: :member
  end
end
