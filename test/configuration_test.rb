# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioTermsAndConditions::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(
      mount_path: "/terms",
      app_name: "Harbor",
      require_scroll_to_end: "true",
      capture_request_provenance: "1"
    )

    assert_equal "/terms", @configuration.mount_path
    assert_equal "Harbor", @configuration.app_name
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
    assert_equal "", configuration.app_name
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
    assert_equal "", result.fetch(:app_name)
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

  def test_app_name_returns_the_set_string
    @configuration.app_name = "Harbor"

    assert_equal "Harbor", @configuration.app_name
  end

  def test_app_name_blank_stays_empty_without_site_settings
    without_site_settings do
      @configuration.app_name = "   "

      assert_equal "", @configuration.app_name
    end
  end

  def test_app_name_falls_back_to_site_settings_name_for
    with_site_settings_name("Harbor") do
      @configuration.app_name = ""

      assert_equal "Harbor", @configuration.app_name
    end
  end

  def test_app_name_set_value_wins_over_site_settings
    with_site_settings_name("Harbor") do
      @configuration.app_name = "Terms Dummy"

      assert_equal "Terms Dummy", @configuration.app_name
    end
  end

  def test_app_name_blank_when_site_settings_has_no_name_for
    with_site_settings_module do
      @configuration.app_name = nil

      assert_equal "", @configuration.app_name
    end
  end

  private

  def without_site_settings
    stash_site_settings
    yield
  ensure
    restore_site_settings
  end

  def with_site_settings_name(name)
    stash_site_settings
    mod = Module.new
    mod.define_singleton_method(:name_for) { |*_args| name }
    Object.const_set(:RecordingStudioSiteSettings, mod)
    yield
  ensure
    restore_site_settings
  end

  def with_site_settings_module
    stash_site_settings
    Object.const_set(:RecordingStudioSiteSettings, Module.new)
    yield
  ensure
    restore_site_settings
  end

  def stash_site_settings
    @stashed_site_settings = Object.const_defined?(:RecordingStudioSiteSettings)
    @site_settings_const = Object.const_get(:RecordingStudioSiteSettings) if @stashed_site_settings
    Object.send(:remove_const, :RecordingStudioSiteSettings) if @stashed_site_settings
  end

  def restore_site_settings
    if Object.const_defined?(:RecordingStudioSiteSettings)
      Object.send(:remove_const, :RecordingStudioSiteSettings)
    end
    Object.const_set(:RecordingStudioSiteSettings, @site_settings_const) if @stashed_site_settings
  end
end
