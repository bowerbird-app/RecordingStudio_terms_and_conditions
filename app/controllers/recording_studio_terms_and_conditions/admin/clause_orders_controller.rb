# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class ClauseOrdersController < BaseController
      include OutlineOrder

      before_action :authorize_outline_write!

      def update
        node = movable_clause
        return refuse_reorder if node.nil?

        Outline.move_clause(node.recording, to_index: target_index, actor: current_admin_actor)
        reorder_response(admin_term_section_path(terms_recording, section.recording))
      end

      private

      def authorize_outline_write!
        authorize_terms_resource!(:edit, record: terms_recording)
      end

      def section
        @section ||= Outline.find_section!(terms_recording, params[:section_id])
      end

      def movable_clause
        node = Outline.find_clause!(terms_recording, params[:moving_recording_id])
        return if node.recording.parent_recording_id.to_s != section.recording.id.to_s

        node
      rescue Outline::Missing
        nil
      end
    end
  end
end
