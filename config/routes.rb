# frozen_string_literal: true

RecordingStudioTermsAndConditions::Engine.routes.draw do
  resource :acceptance, only: %i[show create]
  namespace :admin do
    resources :terms, only: %i[index new create show edit update] do
      member do
        get :changes
        get :preview
        get :text
        post :release
      end
      resource :section_order, only: :update, controller: "section_orders"
      resources :sections, only: %i[index new create show edit update destroy] do
        resource :clause_order, only: :update, controller: "clause_orders"
        resources :clauses, only: %i[new create]
      end
      resources :clauses, only: %i[show edit update destroy]
      resources :users, only: %i[index show], controller: "term_users"
    end
    get "people/:actor_type/:actor_id",
        to: "people#show",
        as: :person,
        constraints: { actor_type: /[A-Za-z][A-Za-z0-9:]*/, actor_id: %r{[^/]+} }
  end

  root to: redirect { |_params, request| "#{request.script_name}/acceptance" }
end
