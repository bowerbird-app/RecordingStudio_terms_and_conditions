# frozen_string_literal: true

RecordingStudioTermsAndConditions::Engine.routes.draw do
  resource :acceptance, only: %i[show create]
  namespace :admin do
    resources :terms, only: %i[index new create show edit update] do
      resources :users, only: :index, controller: "term_users"
    end
  end

  root "acceptances#show"
end
