# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    class Accepted
      def self.call(context)
        ActorRoot.authorize!(context)
        accepted = RecordingStudioTermsAndConditions.accepted?(
          Access.actor_for(context),
          ActorRoot.root(context),
          kind: TermsPayload.kind_from(context.params)
        )

        { accepted: accepted }
      end
    end
  end
end
