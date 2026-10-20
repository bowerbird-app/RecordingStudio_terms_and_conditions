# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    module AcceptancesOverTime
      IDENTIFIER = "terms_acceptances.over_time"
      SCREEN_KEY = "recording_studio_terms_acceptances"
      DEFAULT_WINDOW = :last_4_weeks

      module_function

      def series(context)
        RecordingStudioMetrics::Admin.chart_series(
          IDENTIFIER,
          admin_context: context,
          name: "Agrees",
          **params(context)
        )
      end

      def total(context)
        Array(series(context).dig(0, :data)).sum { |point| point.is_a?(Hash) ? point.fetch(:y, 0).to_i : 0 }
      end

      def params(context)
        values = { scope: :site, site_authorized: true, interval: context.widget_group_by(default: :day) }
        range = context.widget_time_range(default_preset_key: DEFAULT_WINDOW)
        return values if range.blank?

        values.merge(start_at: range.begin, end_at: range.end)
      end
    end
  end
end
