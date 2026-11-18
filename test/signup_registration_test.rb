# frozen_string_literal: true

require "test_helper"

class SignupRegistrationTest < Minitest::Test
  def test_callable_accepts_pending_terms_for_each_signup_method
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

  def test_not_live_skips_that_document_and_accepts_the_rest
    actor = Object.new
    calls = []

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { %i[stale live] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, lambda { |user, terms, provenance|
        raise RecordingStudioTermsAndConditions::NotLive if terms == :stale

        calls << [user, terms, provenance]
      }) do
        assert_nil RecordingStudioTermsAndConditions::SignupRegistration.call(user: actor, method: :password)
      end
    end

    assert_equal [[actor, :live, { "source" => "signup", "method" => "password" }]], calls
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

  def test_callable_does_not_touch_users_signup_config
    source = File.read(
      File.expand_path("../lib/recording_studio_terms_and_conditions/signup_registration.rb", __dir__)
    )
    engine = File.read(
      File.expand_path("../lib/recording_studio_terms_and_conditions/engine.rb", __dir__)
    )

    refute_includes source, "RecordingStudioUser"
    refute_includes source, "signup_notice_partials"
    refute_includes source, "after_registration"
    refute_includes source, "install!"
    refute_includes engine, "SignupRegistration"
    refute_includes engine, "signup_notice_partials"
  end
end
