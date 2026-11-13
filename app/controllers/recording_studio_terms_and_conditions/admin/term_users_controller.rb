# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermUsersController < BaseController
      before_action :authorize_terms_users!

      def index
        @terms = terms_recording.recordable
        @pagy, @versions = paginate_records(AgreementHistory.versions_for(terms_recording))
      end

      def show
        @terms = terms_recording.recordable
        @version = AgreementHistory.find(terms_recording, params[:id])
        return redirect_missing_version if @version.nil?

        @pagy, @acceptances = paginate_table(AgreementHistory.acceptances_for(@version.terms_id))
      end

      private

      def authorize_terms_users!
        authorize_terms_resource!(:users, record: terms_recording)
      end

      def redirect_missing_version
        redirect_to admin_term_users_path(terms_recording), alert: "That version is not on this document."
      end
    end
  end
end
