# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class SectionOrdersController < BaseController
      include OutlineOrder

      before_action :authorize_outline_write!

      def update
        node = Outline.find_section!(terms_recording, params[:moving_recording_id])
        Outline.move_section(node.recording, to_index: target_index, actor: current_admin_actor)
        reorder_response(admin_term_sections_path(terms_recording))
      rescue Outline::Missing
        refuse_reorder
      end

      private

      def authorize_outline_write!
        authorize_terms_resource!(:edit, record: terms_recording)
      end
    end
  end
end
