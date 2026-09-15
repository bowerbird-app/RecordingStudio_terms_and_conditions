# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermUsersController < BaseController
      def index
        @terms = terms_recording.recordable
        @pagy, @acceptances = paginate_table(
          Acceptance.where(terms_recording_id: terms_recording.id).order(accepted_at: :desc)
        )
      end
    end
  end
end
