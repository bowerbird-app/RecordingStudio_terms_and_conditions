# frozen_string_literal: true

require "test_helper"

class SignupRegistrationTest < Minitest::Test
  FakeUsersConfig = Struct.new(:after_registration_hooks, :signup_notice_partials) do
    def initialize
      super([], [])
    end

    def after_registration(hook = nil, &block)
      callable = hook || block
      after_registration_hooks << callable
      callable
    end

    def signup_notice_partials=(value)
      self[:signup_notice_partials] = Array(value)
    end
  end

  def setup
    @config = FakeUsersConfig.new
    @created_user = !Object.const_defined?(:RecordingStudioUser)
    @users = @created_user ? Module.new : RecordingStudioUser
    Object.const_set(:RecordingStudioUser, @users) if @created_user
    singleton = @users.singleton_class
    if singleton.method_defined?(:config) || singleton.private_method_defined?(:config)
      singleton.alias_method(:signup_registration_test_config, :config)
      @aliased_config = true
    end
    config = @config
    @users.define_singleton_method(:config) { config }
  end

  def teardown
    if @created_user
      Object.send(:remove_const, :RecordingStudioUser)
      return
    end

    singleton = @users.singleton_class
    singleton.send(:remove_method, :config)
    return unless @aliased_config

    singleton.alias_method(:config, :signup_registration_test_config)
    singleton.send(:remove_method, :signup_registration_test_config)
  end

  def test_hook_accepts_pending_terms_for_each_signup_method
    actor = Object.new
    calls = []

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { %i[terms privacy] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*args) { calls << args }) do
        %i[password oauth otp].each do |method|
          RecordingStudioTermsAndConditions::SignupRegistration.call(user: actor, method: method)
        end
      end
    end

    provenance = %w[password oauth otp].map { |method| { "source" => "signup", "method" => method } }
    assert_equal provenance.flat_map { |row| [[actor, :terms, row], [actor, :privacy, row]] }, calls
  end

  def test_not_live_does_not_raise
    actor = Object.new

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*) { raise RecordingStudioTermsAndConditions::NotLive }) do
        assert_nil RecordingStudioTermsAndConditions::SignupRegistration.call(user: actor, method: :password)
      end
    end
  end

  def test_other_terms_errors_do_not_raise
    actor = Object.new

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { raise ArgumentError, "terms blew up" }) do
      assert_nil RecordingStudioTermsAndConditions::SignupRegistration.call(user: actor, method: :otp)
    end
  end

  def test_blank_user_skips_acceptance
    calls = []

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*args) { calls << args }) do
        RecordingStudioTermsAndConditions::SignupRegistration.call(user: nil, method: :password)
      end
    end

    assert_empty calls
  end

  def test_install_appends_hook_and_keeps_an_app_hook_registered_first
    seen = []
    app_hook = ->(user:, method:) { seen << [user, method] }
    @config.after_registration(app_hook)

    RecordingStudioTermsAndConditions::SignupRegistration.install!
    RecordingStudioTermsAndConditions::SignupRegistration.install!

    hooks = @config.after_registration_hooks
    assert_equal [app_hook, RecordingStudioTermsAndConditions::SignupRegistration], hooks
    assert_equal ["recording_studio_terms_and_conditions/signup_notice"], @config.signup_notice_partials

    actor = Object.new
    calls = []
    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*args) { calls << args }) do
        hooks.each { |hook| hook.call(user: actor, method: :oauth) }
      end
    end

    assert_equal [[actor, :oauth]], seen
    assert_equal [[actor, :terms, { "source" => "signup", "method" => "oauth" }]], calls
  end

  def test_install_keeps_an_app_hook_registered_after_the_engine
    app_hook = ->(user:, method:) { [user, method] }
    @config.signup_notice_partials = ["host/notice"]

    RecordingStudioTermsAndConditions::SignupRegistration.install!
    @config.after_registration(app_hook)
    RecordingStudioTermsAndConditions::SignupRegistration.install!

    assert_equal [
      RecordingStudioTermsAndConditions::SignupRegistration,
      app_hook
    ], @config.after_registration_hooks
    assert_equal [
      "host/notice",
      "recording_studio_terms_and_conditions/signup_notice"
    ], @config.signup_notice_partials
  end

  def test_app_hook_still_runs_when_terms_acceptance_fails
    seen = []
    app_hook = ->(user:, method:) { seen << [user, method] }
    RecordingStudioTermsAndConditions::SignupRegistration.install!
    @config.after_registration(app_hook)
    actor = Object.new

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*) { raise RecordingStudioTermsAndConditions::NotLive }) do
        @config.after_registration_hooks.each { |hook| hook.call(user: actor, method: :password) }
      end
    end

    assert_equal [[actor, :password]], seen
  end
end
