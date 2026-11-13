# frozen_string_literal: true

RecordingStudioTermsAndConditions::Engine.routes.draw do
  resource :acceptance, only: %i[show create]
  namespace :admin do
    resources :terms, only: %i[index new create show edit update] do
      member do
        get :changes
        get :preview
        post :release
      end
      resources :sections, only: %i[create update destroy] do
        member { post :move }
        resources :clauses, only: :create
      end
      resources :clauses, only: %i[update destroy] do
        member { post :move }
      end
      resources :users, only: :index, controller: "term_users"
    end
    get "people/:actor_type/:actor_id",
        to: "people#show",
        as: :person,
        constraints: { actor_type: /[A-Za-z][A-Za-z0-9:]*/, actor_id: %r{[^/]+} }
  end

  root to: redirect { |_params, request| "#{request.script_name}/acceptance" }
end
