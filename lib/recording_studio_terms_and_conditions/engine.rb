# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioTermsAndConditions

    initializer "recording_studio_terms_and_conditions.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper RecordingStudioTermsAndConditions::ApplicationHelper
        helper RecordingStudioTermsAndConditions::TermsDateHelper
        if defined?(RecordingStudioUser)
          views = RecordingStudioTermsAndConditions::Engine.root.join("app/views").to_s
          prepend_view_path(views) unless view_paths.first.to_s == views
        end
      end
    end

    initializer "recording_studio_terms_and_conditions.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    class << self
      def prepend_users_signup_view_path
        return unless defined?(RecordingStudioUser)
        return unless defined?(ActionController::Base)

        views = root.join("app/views").to_s
        return if ActionController::Base.view_paths.first.to_s == views

        ActionController::Base.prepend_view_path(views)
      end
    end

    initializer "recording_studio_terms_and_conditions.before_initialize",
                before: "recording_studio_terms_and_conditions.load_config" do |_app|
      RecordingStudioTermsAndConditions.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_terms_and_conditions.load_config" do |app|
      EngineConfig.load!(app)
    end

    initializer "recording_studio_terms_and_conditions.after_initialize",
                after: "recording_studio_terms_and_conditions.load_config" do |_app|
      RecordingStudioTermsAndConditions.configuration.hooks.run(:after_initialize, self)
      AcceptanceGateInstaller.call
    end

    initializer "recording_studio_terms_and_conditions.metrics" do
      config.to_prepare { RecordingStudioTermsAndConditions::Metrics.register! }
    end

    initializer "recording_studio_terms_and_conditions.admin_definitions" do
      config.to_prepare { AdminReloader.call }
    end

    initializer "recording_studio_terms_and_conditions.sole_live" do
      config.after_initialize do
        SoleLive.install!
        Published.install!
      end
    end

    initializer "recording_studio_terms_and_conditions.privacy_route" do |app|
      app.routes.append do
        PrivacyRoute.draw!(self)
      end
    end

    initializer "recording_studio_terms_and_conditions.install_runtime" do
      config.to_prepare { EngineRuntime.install! }
    end
  end
end
