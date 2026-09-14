# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermsController < BaseController
      before_action :require_admin_write_access!, only: %i[create update]

      def index
        @terms_recordings = terms_scope
      end

      def new
        @title = ""
        @body = ""
      end

      def create
        parent = terms_parent_root
        if parent.blank?
          flash.now[:alert] = "Pick a workspace first."
          @title = terms_params[:title]
          @body = terms_params[:body]
          return render :new, status: :unprocessable_entity
        end

        recording = parent.record(Terms, actor: current_admin_actor, parent_recording: parent) do |terms|
          terms.title = terms_params[:title]
          terms.body = terms_params[:body]
        end
        redirect_to admin_term_path(recording), notice: "Terms drafted. Publish when they are ready."
      end

      def show
        @terms = terms_recording.recordable
        @acceptances = Acceptance.where(terms_recording_id: terms_recording.id)
                                 .order(accepted_at: :desc)
                                 .limit(50)
      end

      def edit
        @terms = terms_recording.recordable
      end

      def update
        recording = terms_recording.root_recording.revise(terms_recording, actor: current_admin_actor) do |terms|
          terms.title = terms_params[:title]
          terms.body = terms_params[:body]
        end
        redirect_to admin_term_path(recording), notice: "Terms updated."
      end

      private

      def terms_scope
        RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
                                  .includes(:recordable)
                                  .order(updated_at: :desc)
      end

      def terms_params
        params.fetch(:terms, {}).permit(:title, :body)
      end
    end
  end
end
