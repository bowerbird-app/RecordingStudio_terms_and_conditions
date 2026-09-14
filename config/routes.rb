# frozen_string_literal: true

RecordingStudioTermsAndConditions::Engine.routes.draw do
  resource :acceptance, only: %i[show create]
  namespace :admin do
    resources :terms, only: %i[index new create show edit update]
  end

  root "acceptances#show"
end
