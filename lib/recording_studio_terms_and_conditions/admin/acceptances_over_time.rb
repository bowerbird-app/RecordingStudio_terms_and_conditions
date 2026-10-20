# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    module AcceptancesOverTime
      IDENTIFIER = "terms_acceptances.over_time"
      SCREEN_KEY = "recording_studio_terms_acceptances"
      DEFAULT_WINDOW = :last_4_weeks
      CHART_WINDOW = :last_30_days

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
        Array(result.data).filter_map { |row| hash_point(row) if row.is_a?(Hash) }
      end

      def hash_point(row)
        x = first_present(row, :x, "x", :date, "date")
        return unless x

        { x: x, y: first_present(row, :y, "y", :value, "value").to_i }
      end

      def first_present(row, *keys)
        keys.each do |key|
          value = row[key]
          return value unless value.nil?
        end
        nil
      end

      def params(context)
        values = { scope: :site, site_authorized: true, interval: context.widget_group_by(default: :day) }
        range = context.widget_time_range(default_preset_key: CHART_WINDOW)
        return values if range.blank?

        values.merge(start_at: range.begin, end_at: range.end)
      end
    end
  end
end
