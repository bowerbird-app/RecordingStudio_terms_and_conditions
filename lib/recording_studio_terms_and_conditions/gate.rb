# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Clickwrap gate registered on Recording Studio as
  # recording_studio_terms_and_conditions.acceptance.
  # The check follows pending_published_list (live Terms the actor has not accepted).
  module Gate
    GATE_NAME = "recording_studio_terms_and_conditions.acceptance"
    CHECK_NAME = "pending"
    REASON = "pending"

    module_function

    def register!
      return CHECK_NAME if registered?

      RecordingStudio.register_gate(GATE_NAME, CHECK_NAME) do |actor:, root: nil, controller: nil, **|
        decide(actor: actor, root: root, controller: controller)
      end
    end

    def registered?
      RecordingStudio.gate_checks(GATE_NAME).any? { |check| check[:name] == CHECK_NAME }
    end

    def decide(actor:, root: nil, controller: nil, **)
      return true if pending_for(actor, root: root, controller: controller).empty?

      RecordingStudio::GateDecision.deny(redirect_to: redirect_for(controller), reason: REASON)
    end

    def exempt?(controller)
      return true if controller.respond_to?(:devise_controller?) && controller.devise_controller?

      path = controller.controller_path.to_s
      exempt_controllers.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
    end

    def pending_for(actor, **)
      return [] if actor.blank?

      RecordingStudioTermsAndConditions.pending_published_list(actor)
    end

    def after_auth_path(controller, actor)
      decision = RecordingStudio.check_gate(GATE_NAME, actor: actor, controller: controller)
      return if decision.allowed?

      decision.redirect_to || acceptance_path(controller)
    end

    def acceptance_path(controller)
      if controller.respond_to?(:recording_studio_terms_and_conditions)
        controller.recording_studio_terms_and_conditions.acceptance_path
      else
        controller.acceptance_path
      end
    end

    def exempt_controllers
      # Built-in screens plus whatever the host appended.
      RecordingStudioTermsAndConditions.configuration.gate_exempt_controllers
    end

    def redirect_for(controller)
      return if controller.blank?

      acceptance_path(controller)
    end
  end
end
