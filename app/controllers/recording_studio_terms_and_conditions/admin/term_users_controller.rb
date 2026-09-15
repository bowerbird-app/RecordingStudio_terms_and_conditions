# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermUsersController < BaseController
      def index
        @terms = terms_recording.recordable
        @acceptances = Acceptance.where(terms_recording_id: terms_recording.id)
                                 .order(accepted_at: :desc)
                                 .limit(50)
      end
    end
  end
end
