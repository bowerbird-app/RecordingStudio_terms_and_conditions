# frozen_string_literal: true

require "test_helper"

class UsersAfterAuthPathTest < Minitest::Test
  Hook = RecordingStudioTermsAndConditions::UsersAfterAuthPath

  def setup
    @configuration = RecordingStudioTermsAndConditions.configuration
    @previous_flag = @configuration.users_after_auth_path
  end

  def teardown
    @configuration.users_after_auth_path = @previous_flag
    hide_fake_users
  end

  def test_install_wraps_nil_then_a_host_callable_and_a_second_call_is_a_no_op
    config = install_fake_users(nil)
    assert Hook.install!

    wrapped = config.after_auth_path
    assert_instance_of Hook::Callable, wrapped
    assert_nil wrapped.previous

    host = lambda do |controller:, user:|
      "host-#{user}-#{controller}"
    end
    config.after_auth_path = host
    assert Hook.install!

    wrapped = config.after_auth_path
    assert_equal host, wrapped.previous
    controller = Object.new
    RecordingStudioTermsAndConditions::Gate.stub(:after_auth_path, "/agree") do
      assert_equal "/agree", wrapped.call(controller: controller, user: "ada")
    end
    RecordingStudioTermsAndConditions::Gate.stub(:after_auth_path, nil) do
      assert_equal "host-ada-#{controller}", wrapped.call(controller: controller, user: "ada")
    end

    assert Hook.install!
    assert_same wrapped, config.after_auth_path
    refute_instance_of Hook::Callable, wrapped.previous
  end

  def test_install_returns_false_when_the_flag_is_off
    @configuration.users_after_auth_path = false

    assert_equal false, Hook.install!
  end

  def test_install_returns_false_without_raising_when_users_is_not_loaded
    original = String.instance_method(:safe_constantize)
    String.class_eval do
      define_method(:safe_constantize) do
        return nil if self == "::RecordingStudioUser"

        original.bind_call(self)
      end
    end

    assert_equal false, Hook.install!
  ensure
    String.class_eval { define_method(:safe_constantize, original) } if original
  end

  def test_engine_registers_the_initializer_and_the_flag_defaults_to_true
    engine = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/engine.rb", __dir__))
    initializer = RecordingStudioTermsAndConditions::Engine.initializers.find do |entry|
      entry.name == "recording_studio_terms_and_conditions.users_after_auth_path"
    end

    assert initializer
    assert_includes engine, 'initializer "recording_studio_terms_and_conditions.users_after_auth_path"'
    assert_includes engine, "UsersAfterAuthPath.install!"
    assert_equal true, RecordingStudioTermsAndConditions::Configuration.new.users_after_auth_path
  end

  private

  def install_fake_users(current)
    hide_fake_users
    users = Module.new do
      class << self
        attr_accessor :config
      end
    end
    users.config = Struct.new(:after_auth_path).new(current)
    Object.const_set(:RecordingStudioUser, users)
    users.config
  end

  def hide_fake_users
    Object.send(:remove_const, :RecordingStudioUser) if Object.const_defined?(:RecordingStudioUser, false)
  end
end
