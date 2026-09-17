# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermUsersController < BaseController
      before_action :authorize_terms_users!

      def index
        @terms = terms_recording.recordable
        @pagy, @acceptances = paginate_table(
          Acceptance.where(terms_recording_id: terms_recording.id).order(accepted_at: :desc)
        )
      end

      private

      def authorize_terms_users!
        authorize_terms_resource!(:users, record: terms_recording)
      end
    end
  end
end
