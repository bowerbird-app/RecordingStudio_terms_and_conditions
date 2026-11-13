# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class ClausesController < BaseController
      before_action :authorize_outline_read!, only: :show
      before_action :authorize_outline_write!, except: :show

      def show
        @clause = clause
        @unreleased = Outline.unreleased?(terms_recording)
      end

      def new
        section
      end

      def create
        recording = Outline.add_clause(section.recording, body: clause_params[:body], actor: current_admin_actor)
        redirect_to clause_path(recording), notice: "Clause added."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to new_admin_term_section_clause_path(terms_recording, section.recording), alert: invalid_message(e)
      end

      def edit
        @clause = clause
      end

      def update
        Outline.edit_clause(clause.recording, body: clause_params[:body], actor: current_admin_actor)
        redirect_to clause_path(clause.recording), notice: "Clause saved."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_admin_term_clause_path(terms_recording, clause.recording), alert: invalid_message(e)
      end

      def destroy
        parent = clause.recording.parent_recording
        Outline.remove_clause(clause.recording, actor: current_admin_actor)
        redirect_to admin_term_section_path(terms_recording, parent), notice: "Clause removed."
      end

      private

      def authorize_outline_read!
        authorize_terms_resource!(:show, record: terms_recording)
      end

      def authorize_outline_write!
        authorize_terms_resource!(:edit, record: terms_recording)
      end

      def section
        @section ||= Outline.find_section!(terms_recording, params[:section_id])
      end

      def clause
        @clause ||= Outline.find_clause!(terms_recording, params[:id])
      end

      def clause_params
        params.fetch(:clause, {}).permit(:body)
      end

      def clause_path(recording)
        admin_term_clause_path(terms_recording, recording)
      end

      def invalid_message(error)
        error.record.errors.full_messages.to_sentence
      end
    end
  end
end
