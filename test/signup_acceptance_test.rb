# frozen_string_literal: true

require "test_helper"

class SignupAcceptanceTest < Minitest::Test
  class FakeRegistrationsController
    prepend RecordingStudioTermsAndConditions::SignupAcceptance

    attr_accessor :params, :finished_user, :root

    def initialize(params: {}, actor:, root: :workspace)
      @params = params
      @actor = actor
      @root = root
    end

    def create_password
      finish_sign_up!(@actor)
    end

    def finish_sign_up!(user)
      @finished_user = user
    end
  end

  def test_create_password_accepts_pending_terms_with_continue_notice_source
    actor = Object.new
    calls = []
    controller = FakeRegistrationsController.new(actor: actor)

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*args) { calls << args }) do
        RecordingStudioTermsAndConditions::Gate.stub(:root_for_signup, :workspace) do
          controller.create_password
        end
      end
    end

    assert_equal actor, controller.finished_user
    assert_equal [[actor, :terms, { "source" => "continue_notice" }]], calls
  end

  def test_create_password_accepts_without_agreed_param
    actor = Object.new
    calls = []
    controller = FakeRegistrationsController.new(params: {}, actor: actor)

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*args) { calls << args }) do
        RecordingStudioTermsAndConditions::Gate.stub(:root_for_signup, :workspace) do
          controller.create_password
        end
      end
    end

    assert_equal actor, controller.finished_user
    assert_equal [[actor, :terms, { "source" => "continue_notice" }]], calls
  end

  def test_not_live_does_not_raise_on_signup
    actor = Object.new
    controller = FakeRegistrationsController.new(actor: actor)

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*) { raise RecordingStudioTermsAndConditions::NotLive }) do
        RecordingStudioTermsAndConditions::Gate.stub(:root_for_signup, :workspace) do
          controller.create_password
        end
      end
    end

    assert_equal actor, controller.finished_user
  end

  def test_finish_sign_up_from_other_paths_does_not_accept
    actor = Object.new
    calls = []
    controller = FakeRegistrationsController.new(actor: actor)

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [:terms] }) do
      RecordingStudioTermsAndConditions.stub(:accept!, ->(*args) { calls << args }) do
        controller.finish_sign_up!(actor)
      end
    end

    assert_equal actor, controller.finished_user
    assert_empty calls
  end
end
