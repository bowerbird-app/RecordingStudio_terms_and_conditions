# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    module OutlineOrder
      private

      def target_index
        raw = params[:target_position].presence || params[:to_index]
        position = Integer(raw, exception: false)
        return 0 if position.nil?
        return position if params[:target_position].blank?

        [position - 1, 0].max
      end

      def reorder_response(return_to)
        if json_reorder?
          render json: { ok: true }
        else
          redirect_to return_to, notice: "Order saved."
        end
      end

      def json_reorder?
        request.format.json? || request.headers["Accept"].to_s.include?("application/json")
      end

      def refuse_reorder
        if json_reorder?
          render json: { ok: false }, status: :unprocessable_entity
        else
          redirect_back fallback_location: admin_term_path(terms_recording), alert: "Nothing to reorder."
        end
      end
    end
  end
end
