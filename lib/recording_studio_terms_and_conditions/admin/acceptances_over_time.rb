# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    module AcceptancesOverTime
      IDENTIFIER = "terms_acceptances.over_time"
      SCREEN_KEY = "recording_studio_terms_acceptances"
      DEFAULT_WINDOW = :last_4_weeks

      module_function

      def series(context)
        result = RecordingStudioMetrics::Admin.execute(
          IDENTIFIER,
          admin_context: context,
          **params(context)
        )
        [{ name: "Agrees", data: points_from(result) }]
      end

      def total(context)
        Array(series(context).dig(0, :data)).sum { |point| point.is_a?(Hash) ? point.fetch(:y, 0).to_i : 0 }
      end

      def points_from(result)
        Array(result.data).filter_map { |row| point_from(row) }
      end

      def point_from(row)
        if row.is_a?(Hash)
          x = row[:x] || row["x"] || row[:date] || row["date"]
          y = row[:y] || row["y"] || row[:value] || row["value"]
          return unless x

          { x: x, y: y.to_i }
        elsif row.is_a?(Array) && row.size >= 2
          { x: row[0], y: row[1].to_i }
        end
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
