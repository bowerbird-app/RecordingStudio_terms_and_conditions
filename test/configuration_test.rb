# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioTermsAndConditions::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(
      mount_path: "/terms",
      require_scroll_to_end: "true",
      capture_request_provenance: "1"
    )

    assert_equal "/terms", @configuration.mount_path
    assert_equal true, @configuration.require_scroll_to_end
    assert_equal true, @configuration.capture_request_provenance
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", mount_path: "/addons/terms")

    refute_respond_to @configuration, :unknown_key
    refute_respond_to @configuration, :api_key
    refute_respond_to @configuration, :enable_feature_x
    refute_respond_to @configuration, :timeout
    refute_respond_to @configuration, :required_categories
    assert_equal "/addons/terms", @configuration.mount_path
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:mount_path], @configuration.mount_path
    assert_equal original[:require_scroll_to_end], @configuration.require_scroll_to_end
    assert_equal original[:capture_request_provenance], @configuration.capture_request_provenance
  end

  def test_initialize_uses_product_defaults
    configuration = RecordingStudioTermsAndConditions::Configuration.new

    assert_equal "/recording_studio_terms_and_conditions", configuration.mount_path
    assert_equal false, configuration.require_scroll_to_end
    assert_equal false, configuration.capture_request_provenance
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("mount_path" => "/hosted-terms", "require_scroll_to_end" => false)

    assert_equal "/hosted-terms", @configuration.mount_path
    assert_equal false, @configuration.require_scroll_to_end
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
    assert_equal false, result.fetch(:require_scroll_to_end)
    assert_equal false, result.fetch(:capture_request_provenance)
    refute result.key?(:required_categories)
    refute result.key?(:api_key)
    refute result.key?(:enable_feature_x)
    refute result.key?(:timeout)
  end

  def test_configure_without_block_is_safe
    RecordingStudioTermsAndConditions.configure

    assert_kind_of RecordingStudioTermsAndConditions::Configuration, RecordingStudioTermsAndConditions.configuration
  end
end
