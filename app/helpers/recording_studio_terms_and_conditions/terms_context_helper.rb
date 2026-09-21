# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module TermsContextHelper
    def recording_studio_terms_pending_list(actor, root, pending)
      return Array(pending).compact unless pending.nil?

      list = RecordingStudioTermsAndConditions.pending_published_list(actor, root)
      return list if list.any?

      Array(RecordingStudioTermsAndConditions.current_published_for(root)).compact
    end

    def recording_studio_terms_agree_root
      Gate.root_for(controller)
    end

    def recording_studio_terms_agree_actor
      return current_user if respond_to?(:current_user) && current_user

      Current.actor if defined?(Current)
    end
  end
end
