# frozen_string_literal: true

require "test_helper"
require "recording_studio_terms_and_conditions/admin"

class AdminAcceptancesOverTimeWidgetTest < Minitest::Test
  FakeRangeContext = Struct.new(:interval, :range, :preset_key) do
    def widget_group_by(default: :day)
      interval || default
    end

    def widget_time_range(default_preset_key: nil, **)
      self.preset_key = default_preset_key
      range
    end
  end

  def test_chart_window_is_last_30_days
    assert_equal :last_30_days, RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime::CHART_WINDOW
    assert_equal :last_4_weeks, RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime::DEFAULT_WINDOW
  end

  def test_over_time_params_default_to_last_30_days
    context = FakeRangeContext.new(:day, nil, nil)

    RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime.params(context)

    assert_equal :last_30_days, context.preset_key
  end

  def test_over_time_params_authorize_site_metrics_and_pass_the_window
    range = Time.utc(2026, 10, 13)..Time.utc(2026, 10, 19)
    context = FakeRangeContext.new(:day, range, nil)

    params = RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime.params(context)

    assert_equal :site, params[:scope]
    assert_equal true, params[:site_authorized]
    assert_equal :day, params[:interval]
    assert_equal range.begin, params[:start_at]
    assert_equal range.end, params[:end_at]
  end

  def test_over_time_params_omit_bounds_when_admin_has_no_period
    context = FakeRangeContext.new(:week, nil, nil)

    params = RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime.params(context)

    refute params.key?(:start_at)
    refute params.key?(:end_at)
    assert_equal :week, params[:interval]
  end

  def test_over_time_total_sums_the_metrics_series
    helper = RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime
    series = [{ name: "Agrees", data: [{ x: "2026-10-18", y: 2 }, { x: "2026-10-19", y: 3 }] }]
    helper.stub(:series, series) do
      assert_equal 5, helper.total(Object.new)
    end
  end

  def test_points_from_maps_metric_date_and_value_keys
    helper = RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime
    result = Struct.new(:data).new(
      [{ date: "2026-10-18", value: 2 }, { "date" => "2026-10-19", "value" => 4 }]
    )

    assert_equal(
      [{ x: "2026-10-18", y: 2 }, { x: "2026-10-19", y: 4 }],
      helper.points_from(result)
    )
  end
end
