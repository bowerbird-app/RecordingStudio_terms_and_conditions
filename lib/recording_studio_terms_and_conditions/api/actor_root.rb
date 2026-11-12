# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    module ActorRoot
      module_function

      def authorize!(context)
        context.access_grant.authorize!(recording: context.recording, role: :view)
      end

      def actor(context)
        context.access_grant.actor
      end

      def root(context)
        context.recording
      end
    end
  end
end
