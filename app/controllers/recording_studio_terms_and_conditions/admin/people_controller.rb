# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class PeopleController < BaseController
      def show
        @acceptances = Acceptance.where(actor_type: actor_type, actor_id: actor_id)
                                 .order(accepted_at: :desc)
        @actor = @acceptances.first&.actor
        return head :not_found if @actor.blank?

        @rows = agreement_rows
      end

      private

      def actor_type
        params[:actor_type].to_s
      end

      def actor_id
        params[:actor_id].to_s
      end

      def agreement_rows
        terms_by_id = Terms.where(id: @acceptances.map(&:terms_id)).index_by(&:id)
        @acceptances.map do |acceptance|
          terms = terms_by_id[acceptance.terms_id]
          {
            title: terms&.title.presence || "A past version",
            type: terms&.kind_label.presence || "Terms",
            agreed: acceptance.accepted_at
          }
        end
      end
    end
  end
end
