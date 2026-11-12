# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    class PendingPublishedList
      def self.call(context)
        ActorRoot.authorize!(context)
        list = RecordingStudioTermsAndConditions.pending_published_list(
          Access.actor_for(context),
          ActorRoot.root(context)
        )

        { terms: list.map { |terms| TermsPayload.terms_hash(terms) } }
      end
    end
  end
end
