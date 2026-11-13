# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class SectionsController < BaseController
      before_action :authorize_outline_read!, only: %i[index show]
      before_action :authorize_outline_write!, except: %i[index show]

      def index
        prepare_outline!
        assign_outline
      end

      def show
        @section = section
        assign_outline
      end

      def new; end

      def create
        recording = Outline.add_section(terms_recording, heading: section_params[:heading], actor: current_admin_actor)
        redirect_to admin_term_section_path(terms_recording, recording), notice: "Section added."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to new_admin_term_section_path(terms_recording), alert: e.record.errors.full_messages.to_sentence
      end

      def update
        Outline.edit_section(section.recording, heading: section_params[:heading], actor: current_admin_actor)
        redirect_to section_path, notice: "Heading saved."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to section_path, alert: e.record.errors.full_messages.to_sentence
      end

      def destroy
        Outline.remove_section(section.recording, actor: current_admin_actor)
        redirect_to admin_term_sections_path(terms_recording), notice: "Section removed."
      end

      private

      def authorize_outline_read!
        authorize_terms_resource!(:show, record: terms_recording)
      end

      def authorize_outline_write!
        authorize_terms_resource!(:edit, record: terms_recording)
      end

      def prepare_outline!
        return if Outline.sections(terms_recording).any?
        return unless admin_authorized?(:edit)

        Outline.seed_recording!(terms_recording, actor: current_admin_actor)
      end

      def assign_outline
        @sections = Outline.sections(terms_recording)
        @changes = Outline.changes(terms_recording)
        @unreleased = Outline.unreleased?(terms_recording)
        @terms = terms_recording.recordable
      end

      def section
        @section ||= Outline.find_section!(terms_recording, params[:id])
      end

      def section_params
        params.fetch(:section, {}).permit(:heading)
      end

      def section_path
        admin_term_section_path(terms_recording, section.recording)
      end
    end
  end
end
