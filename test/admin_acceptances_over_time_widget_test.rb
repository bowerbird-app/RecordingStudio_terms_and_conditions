# frozen_string_literal: true

require "test_helper"
require "recording_studio_terms_and_conditions/admin"

class AdminAcceptancesOverTimeWidgetTest < Minitest::Test
  FakeRangeContext = Struct.new(:interval, :range) do
    def widget_group_by(default: :day)
      interval || default
    end

    def widget_time_range(**)
      range
    end
  end

  def test_over_time_params_authorize_site_metrics_and_pass_the_week_window
    range = Time.utc(2026, 10, 13)..Time.utc(2026, 10, 19)
    context = FakeRangeContext.new(:day, range)

    params = RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime.params(context)

    assert_equal :site, params[:scope]
    assert_equal true, params[:site_authorized]
    assert_equal :day, params[:interval]
    assert_equal range.begin, params[:start_at]
    assert_equal range.end, params[:end_at]
  end

  def test_over_time_params_omit_bounds_when_admin_has_no_period
    context = FakeRangeContext.new(:week, nil)

    params = RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime.params(context)

    refute params.key?(:start_at)
    refute params.key?(:end_at)
    assert_equal :week, params[:interval]
  end

  def test_over_time_total_sums_the_metrics_series
    helper = RecordingStudioTermsAndConditions::Admin::AcceptancesOverTime
    series = [{ name: "Agrees", data: [["2026-10-18", 2], ["2026-10-19", 3]] }]
    helper.stub(:series, series) do
      assert_equal 5, helper.total(Object.new)
    end
  end
end
