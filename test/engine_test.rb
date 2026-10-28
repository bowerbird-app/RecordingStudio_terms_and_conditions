# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioTermsAndConditions.instance_variable_get(:@configuration)
    RecordingStudioTermsAndConditions.instance_variable_set(
      :@configuration,
      RecordingStudioTermsAndConditions::Configuration.new
    )
  end

  def teardown
    RecordingStudioTermsAndConditions.configuration.hooks.clear!
    RecordingStudioTermsAndConditions.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_assets_initializer_adds_javascript_path
    paths = []
    assets = Struct.new(:paths).new(paths)
    app = Struct.new(:config).new(Struct.new(:assets).new(assets))

    find_initializer("recording_studio_terms_and_conditions.assets").block.call(app)

    assert_includes paths, RecordingStudioTermsAndConditions::Engine.root.join("app/javascript")
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioTermsAndConditions.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioTermsAndConditions.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_terms_and_conditions.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_terms_and_conditions.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_config_sources_and_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudioTermsAndConditions.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    xcfg = Struct.new(:recording_studio_terms_and_conditions).new({ require_scroll_to_end: true })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { mount_path: "/from-yaml", capture_request_provenance: true }
      end
    end.new(app_config)

    find_initializer("recording_studio_terms_and_conditions.load_config").block.call(app)

    assert hook_called
    assert_equal RecordingStudioTermsAndConditions.configuration, hook_payload
    assert_equal "/from-yaml", RecordingStudioTermsAndConditions.configuration.mount_path
    assert_equal true, RecordingStudioTermsAndConditions.configuration.capture_request_provenance
    assert_equal true, RecordingStudioTermsAndConditions.configuration.require_scroll_to_end
  end

  def test_load_config_handles_errors_and_each_pair_fallback
    pair_config = Class.new do
      def each_pair
        yield(:mount_path, "/from-pairs")
      end
    end.new

    xcfg = Struct.new(:recording_studio_terms_and_conditions).new(pair_config)
    app_config = Struct.new(:x).new(xcfg)

    app = Struct.new(:config) do
      def config_for(_name)
        raise "missing file"
      end
    end.new(app_config)

    logs = with_logged_warnings do
      find_initializer("recording_studio_terms_and_conditions.load_config").block.call(app)
    end

    assert_equal "/from-pairs", RecordingStudioTermsAndConditions.configuration.mount_path
    assert(logs.any? { |line| line.include?("config_for skipped") && line.include?("RuntimeError") })
  end

  def test_load_config_logs_each_pair_errors
    bad_pair_config = Class.new do
      def each_pair
        raise TypeError, "bad pair"
      end
    end.new

    xcfg = Struct.new(:recording_studio_terms_and_conditions).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { mount_path: "/ok" }
      end
    end.new(app_config)

    logs = with_logged_warnings do
      find_initializer("recording_studio_terms_and_conditions.load_config").block.call(app)
    end

    assert_equal "/ok", RecordingStudioTermsAndConditions.configuration.mount_path
    assert(logs.any? { |line| line.include?("config.x skipped") && line.include?("TypeError") })
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config).new(Object.new)

    find_initializer("recording_studio_terms_and_conditions.load_config").block.call(app)

    assert_equal "/recording_studio_terms_and_conditions", RecordingStudioTermsAndConditions.configuration.mount_path
    assert_equal false, RecordingStudioTermsAndConditions.configuration.require_scroll_to_end
    assert_equal false, RecordingStudioTermsAndConditions.configuration.capture_request_provenance
  end

  def test_load_config_ignores_non_enumerable_yaml_and_merge_errors
    yaml = Class.new do
      def each
        raise "bad yaml"
      end
    end.new

    xcfg = Struct.new(:recording_studio_terms_and_conditions).new({ mount_path: "/from-x" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      attr_accessor :yaml

      def config_for(_name)
        @yaml
      end
    end.new(app_config)
    app.yaml = yaml

    logs = with_logged_warnings do
      find_initializer("recording_studio_terms_and_conditions.load_config").block.call(app)
    end

    assert_equal "/from-x", RecordingStudioTermsAndConditions.configuration.mount_path
    assert(logs.any? { |line| line.include?("config yaml skipped") && line.include?("RuntimeError") })
  end

  def test_runtime_initializer_registers_to_prepare
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    RecordingStudioTermsAndConditions::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_terms_and_conditions.install_runtime").block.call
    end

    assert_equal 1, to_prepare_blocks.size
  end

  def test_does_not_ship_model_or_controller_extension_applicators
    engine = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/engine.rb", __dir__))

    refute_includes engine, "apply_extensions"
    refute_includes engine, "class_eval"
    refute_includes engine, "apply_model_extensions"
    refute_includes engine, "apply_controller_extensions"
    refute RecordingStudioTermsAndConditions::Engine.respond_to?(:apply_model_extensions)
    refute RecordingStudioTermsAndConditions::Engine.respond_to?(:apply_controller_extensions)
  end

  def test_force_acceptance_initializer_installs_the_gate
    initializer = find_initializer("recording_studio_terms_and_conditions.install_runtime")

    assert initializer
    RecordingStudioTermsAndConditions::AcceptanceGateInstaller.call

    host = "::ApplicationController".safe_constantize
    auth = "RecordingStudioUser::Auth::BaseController".safe_constantize
    registrations = "RecordingStudioUser::Auth::RegistrationsController".safe_constantize
    assert_includes host.ancestors, RecordingStudioTermsAndConditions::ForcesAcceptance if host
    assert_includes auth.ancestors, RecordingStudioTermsAndConditions::UsersAuthRedirect if auth
    assert_includes registrations.ancestors, RecordingStudioTermsAndConditions::SignupAcceptance if registrations
  end

  private

  def with_logged_warnings(&)
    logs = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message| logs << message.to_s }
    Rails.stub(:logger, logger, &)
    logs
  end

  def find_initializer(name)
    RecordingStudioTermsAndConditions::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
