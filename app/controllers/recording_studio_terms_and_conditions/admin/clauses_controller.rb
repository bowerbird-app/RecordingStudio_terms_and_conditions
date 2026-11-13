# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class ClausesController < BaseController
      before_action :authorize_outline_write!

      def create
        Outline.add_clause(section.recording, body: clause_params[:body], actor: current_admin_actor)
        redirect_to edit_admin_term_path(terms_recording), notice: "Clause added."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_admin_term_path(terms_recording), alert: e.record.errors.full_messages.to_sentence
      end

      def update
        Outline.edit_clause(clause.recording, body: clause_params[:body], actor: current_admin_actor)
        redirect_to edit_admin_term_path(terms_recording), notice: "Clause saved."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_admin_term_path(terms_recording), alert: e.record.errors.full_messages.to_sentence
      end

      def destroy
        Outline.remove_clause(clause.recording, actor: current_admin_actor)
        redirect_to edit_admin_term_path(terms_recording), notice: "Clause removed."
      end

      def move
        destination = section_destination
        Outline.move_clause(
          clause.recording,
          to_index: params[:to_index],
          actor: current_admin_actor,
          section_recording: destination
        )
        redirect_to edit_admin_term_path(terms_recording)
      end

      private

      def authorize_outline_write!
        authorize_terms_resource!(:edit, record: terms_recording)
      end

      def section
        @section ||= Outline.find_section!(terms_recording, params[:section_id])
      end

      def clause
        @clause ||= Outline.find_clause!(terms_recording, params[:id])
      end

      def section_destination
        return if params[:section_id].blank?

        Outline.find_section!(terms_recording, params[:section_id]).recording
      end

      def clause_params
        params.fetch(:clause, {}).permit(:body)
      end
    end
  end
end
