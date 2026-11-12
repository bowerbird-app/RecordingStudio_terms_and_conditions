# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    class CurrentPublishedFor
      def self.call(context)
        ActorRoot.authorize!(context)
        terms = RecordingStudioTermsAndConditions.current_published_for(
          ActorRoot.root(context),
          kind: TermsPayload.kind_from(context.params)
        )

        { terms: TermsPayload.terms_hash(terms) }
      end
    end
  end
end
