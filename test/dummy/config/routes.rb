Rails.application.routes.draw do
  devise_for :users,
             skip: %i[sessions registrations passwords],
             controllers: {
               confirmations: "recording_studio_user/auth/confirmations"
             }
  recording_studio_user_auth_for :users

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudioUser::Engine => RecordingStudioUser.config.mount_path, as: :recording_studio_users
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
  mount RecordingStudioTermsAndConditions::Engine, at: "/recording_studio_terms_and_conditions"
  mount RecordingStudioAccessible::Engine, at: "/admin/access"
  mount RecordingStudioPublishable::Engine, at: "/", as: :recording_studio_publishable
  recording_studio_admin_for :admin, at: "/admin", root_section: :terms

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "docs/install", to: "docs#install", as: :docs_install
  get "docs/config", to: "docs#configuration", as: :docs_config
  get "docs/recordable_types", to: "docs#recordable_types", as: :docs_recordable_types
  get "docs/recordings_tree", to: "docs#recordings_tree", as: :docs_recordings_tree
  get "docs/gem_views", to: "docs#gem_views", as: :docs_gem_views
  get "docs/methods", to: "docs#methods", as: :docs_methods
  get "agree_helper", to: "agree_helpers#show", as: :agree_helper
  post "agree_helper", to: "agree_helpers#create"

  # Defines the root path route ("/")
  root "home#index"
end
