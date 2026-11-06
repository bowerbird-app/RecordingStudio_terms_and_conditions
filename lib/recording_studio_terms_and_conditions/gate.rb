# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Shared skip list and path helpers for the clickwrap gate.
  # required? follows pending_published_list (live Terms the actor has not accepted).
  module Gate
    EXEMPT_PREFIXES = %w[
      recording_studio_terms_and_conditions/acceptances
      recording_studio_terms_and_conditions/admin
      recording_studio_terms_and_conditions/published_terms
      agree_helpers
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
      pending_for(controller, actor).any?
    end

    def pending_for(controller, actor)
      root = root_for_acceptance(controller)
      return [] if actor.blank? || root.blank?

      RecordingStudioTermsAndConditions.pending_published_list(actor, root)
    end

    def after_auth_path(controller, actor)
      refresh_root(controller, actor)
      return unless required?(controller, actor)

      acceptance_path(controller)
    end

    def refresh_root(controller, actor)
      return unless defined?(RecordingStudio::RootSwitchable::Current)

      RecordingStudio::RootSwitchable::Current.actor = actor if actor
      if controller.respond_to?(:resolve_recording_studio_root_switchable_current, true)
        controller.send(:resolve_recording_studio_root_switchable_current)
      elsif RecordingStudio::RootSwitchable.respond_to?(:resolve_current_root)
        RecordingStudio::RootSwitchable.resolve_current_root(controller: controller, actor: actor)
      end
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

      if controller.respond_to?(:current_root_recording, true)
        recording = controller.send(:current_root_recording)
        return recording if recording
      end

      switchable_current_root
    end

    def switchable_current_root
      return unless defined?(RecordingStudio::RootSwitchable)

      RecordingStudio::RootSwitchable.current_root_recordable ||
        RecordingStudio::RootSwitchable.current_root_recording
    end

    def root_for_signup(controller)
      root_for_acceptance(controller)
    end

    def root_for_acceptance(controller)
      actor = actor_from(controller)
      refresh_root(controller, actor)
      current = root_for(controller)
      return current if current.present? && live_terms_on?(current)

      first_root_with_live_terms(actor) || current
    end

    def first_root_with_live_terms(actor = nil)
      accessible_root_recordings_for(actor).each do |root|
        return root.recordable if live_terms_on?(root)
      end

      nil
    end

    def actor_from(controller)
      if controller.respond_to?(:current_user)
        user = controller.current_user
        return user if user.present?
      end

      Current.actor if defined?(Current)
    end

    def accessible_root_recordings_for(actor)
      return [] if actor.blank?
      return [] unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end

    def live_terms_on?(root)
      RecordingStudioTermsAndConditions.current_published_for(root).present? ||
        RecordingStudioTermsAndConditions.pending_published_list(nil, root).any?
    end
  end
end
