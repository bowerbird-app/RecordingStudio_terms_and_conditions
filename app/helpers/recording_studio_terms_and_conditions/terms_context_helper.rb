# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module TermsContextHelper
    def recording_studio_terms_pending_list(actor, pending)
      return Array(pending).compact unless pending.nil?

      list = RecordingStudioTermsAndConditions.pending_published_list(actor)
      return list if list.any?

      RecordingStudioTermsAndConditions.current_published_by_kind.values.compact
    end

    def recording_studio_terms_agree_actor
      return current_user if respond_to?(:current_user) && current_user

      nil
    end

    # Recording Studio Users still asks for a signup root. The document lives on
    # the shared library, so the root it used to pass is ignored.
    def recording_studio_terms_signup_root
      RecordingStudioTermsAndConditions.library_root
    end
  end
end
