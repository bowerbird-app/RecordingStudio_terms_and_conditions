# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    class AcceptPending
      def self.call(context)
        ActorRoot.authorize!(context)
        actor = Access.actor_for(context)
        root = ActorRoot.root(context)
        versions = RecordingStudioTermsAndConditions.pending_published_list(actor, root)
        versions = live_versions(root) if versions.empty?

        {
          receipts: versions.map do |terms|
            RecordingStudioTermsAndConditions.accept!(actor, terms, { "source" => "api" }).receipt_contract
          end
        }
      end

      def self.live_versions(root)
        RecordingStudioTermsAndConditions::Terms::KINDS.filter_map do |kind|
          RecordingStudioTermsAndConditions.current_published_for(root, kind: kind)
        end
      end
      private_class_method :live_versions
    end
  end
end
