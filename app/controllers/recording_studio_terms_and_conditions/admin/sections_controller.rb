# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class SectionsController < BaseController
      before_action :authorize_outline_write!

      def create
        Outline.add_section(terms_recording, heading: section_params[:heading], actor: current_admin_actor)
        redirect_to edit_admin_term_path(terms_recording), notice: "Section added."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_admin_term_path(terms_recording), alert: e.record.errors.full_messages.to_sentence
      end

      def update
        Outline.edit_section(section.recording, heading: section_params[:heading], actor: current_admin_actor)
        redirect_to edit_admin_term_path(terms_recording), notice: "Section saved."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to edit_admin_term_path(terms_recording), alert: e.record.errors.full_messages.to_sentence
      end

      def destroy
        Outline.remove_section(section.recording, actor: current_admin_actor)
        redirect_to edit_admin_term_path(terms_recording), notice: "Section removed."
      end

      def move
        Outline.move_section(section.recording, to_index: params[:to_index], actor: current_admin_actor)
        redirect_to edit_admin_term_path(terms_recording)
      end

      private

      def authorize_outline_write!
        authorize_terms_resource!(:edit, record: terms_recording)
      end

      def section
        @section ||= Outline.find_section!(terms_recording, params[:id])
      end

      def section_params
        params.fetch(:section, {}).permit(:heading)
      end
    end
  end
end
