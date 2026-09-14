# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Shared skip list and path helpers for the clickwrap gate.
  module Gate
    EXEMPT_PREFIXES = %w[
      recording_studio_terms_and_conditions/acceptances
      recording_studio_terms_and_conditions/admin
      recording_studio_terms_and_conditions/published_terms
      recording_studio_publishable
      recording_studio_admin
      recording_studio_accessible
      recording_studio_root_switchable
      recording_studio_user/auth
      recording_studio_user/omniauth
      devise
      rails/health
    ].freeze

    module_function

    def exempt?(controller)
      return true if controller.respond_to?(:devise_controller?) && controller.devise_controller?

      path = controller.controller_path.to_s
      EXEMPT_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
    end

    def required?(controller, actor)
      root = root_for(controller)
      return false if actor.blank? || root.blank?

      RecordingStudioTermsAndConditions.requires_acceptance?(actor, root)
    end

    def after_auth_path(controller, actor)
      return unless required?(controller, actor)

      acceptance_path(controller)
    end

    def acceptance_path(controller)
      if controller.respond_to?(:recording_studio_terms_and_conditions)
        controller.recording_studio_terms_and_conditions.acceptance_path
      else
        controller.acceptance_path
      end
    end

    def root_for(controller)
      if controller.respond_to?(:current_root_recordable, true)
        recordable = controller.send(:current_root_recordable)
        return recordable if recordable
      end

      return unless controller.respond_to?(:current_root_recording, true)

      controller.send(:current_root_recording)
    end
  end
end
