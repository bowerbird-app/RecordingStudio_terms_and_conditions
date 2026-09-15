# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermsController < BaseController
      before_action :require_admin_write_access!, only: %i[create update]

      def index
        @pagy, @terms_recordings = paginate_table(terms_scope)
      end

      def new
        @title = ""
        @body = ""
        @change_note = ""
      end

      def create
        return render_missing_workspace if terms_parent_root.blank?

        recording = draft_terms!(terms_parent_root)
        redirect_to admin_term_path(recording), notice: "Terms drafted. Publish when they are ready."
      end

      def show
        @terms = terms_recording.recordable
      end

      def edit
        @terms = terms_recording.recordable
      end

      def update
        recording = terms_recording.root_recording.revise(terms_recording, actor: current_admin_actor) do |terms|
          assign_terms_fields(terms)
        end
        redirect_to admin_term_path(recording), notice: "Terms updated."
      end

      private

      def terms_scope
        RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
                                  .includes(:recordable)
                                  .order(updated_at: :desc)
      end

      def draft_terms!(parent)
        parent.record(Terms, actor: current_admin_actor, parent_recording: parent) do |terms|
          assign_terms_fields(terms)
        end
      end

      def render_missing_workspace
        flash.now[:alert] = "Pick a workspace first."
        @title = terms_params[:title]
        @body = terms_params[:body]
        @change_note = terms_params[:change_note]
        render :new, status: :unprocessable_entity
      end

      def assign_terms_fields(terms)
        terms.title = terms_params[:title]
        terms.body = terms_params[:body]
        terms.change_note = terms_params[:change_note].presence
      end

      def terms_params
        params.fetch(:terms, {}).permit(:title, :body, :change_note)
      end
    end
  end
end
