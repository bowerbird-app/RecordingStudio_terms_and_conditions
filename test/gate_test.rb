# frozen_string_literal: true

require "test_helper"

class GateTest < Minitest::Test
  FakeController = Struct.new(:controller_path, :devise_flag) do
    def devise_controller?
      devise_flag
    end
  end

  def test_exempts_clickwrap_auth_and_operator_screens
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_terms_and_conditions/acceptances", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_user/auth/registrations", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("agree_helpers", false))
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_terms_and_conditions/admin/terms", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_terms_and_conditions/published_terms", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_publishable/publishables", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("devise/sessions", false))
    assert RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("home", true))
    refute RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("home", false))
    refute RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("docs", false))
  end

  def test_after_auth_path_is_nil_without_a_root_or_actor
    controller = Object.new
    def controller.current_root_recordable
      nil
    end

    assert_nil RecordingStudioTermsAndConditions::Gate.after_auth_path(controller, :actor)
    assert_nil RecordingStudioTermsAndConditions::Gate.after_auth_path(controller, nil)
  end

  def test_acceptance_path_prefers_the_mounted_engine_helper
    helper = Object.new
    def helper.acceptance_path
      "/mounted-agree"
    end
    controller = Object.new
    controller.define_singleton_method(:recording_studio_terms_and_conditions) { helper }

    assert_equal "/mounted-agree", RecordingStudioTermsAndConditions::Gate.acceptance_path(controller)
  end

  def test_acceptance_path_falls_back_to_the_local_helper
    controller = Object.new
    def controller.acceptance_path
      "/local-agree"
    end

    assert_equal "/local-agree", RecordingStudioTermsAndConditions::Gate.acceptance_path(controller)
  end

  def test_root_for_prefers_the_recordable_then_the_recording
    both = Object.new
    def both.current_root_recordable
      :workspace
    end

    def both.current_root_recording
      :recording
    end
    recording_only = Object.new
    def recording_only.current_root_recording
      :recording
    end

    assert_equal :workspace, RecordingStudioTermsAndConditions::Gate.root_for(both)
    assert_equal :recording, RecordingStudioTermsAndConditions::Gate.root_for(recording_only)
    assert_equal :workspace, RecordingStudioTermsAndConditions::Gate.root_for_signup(both)
  end

  def test_users_auth_redirect_falls_through_when_acceptance_is_not_required
    controller = Class.new do
      prepend RecordingStudioTermsAndConditions::UsersAuthRedirect

      def after_sign_in_path_for(_resource)
        "/after-in"
      end

      def after_sign_up_path_for(_resource)
        "/after-up"
      end

      def current_root_recordable
        nil
      end
    end.new

    assert_equal "/after-in", controller.after_sign_in_path_for(:user)
    assert_equal "/after-up", controller.after_sign_up_path_for(:user)
  end

  def test_gate_files_reuse_domain_helpers
    gate = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/gate.rb", __dir__))
    forces = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/forces_acceptance.rb", __dir__))
    users = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/users_auth_redirect.rb", __dir__))

    assert_includes gate, "pending_published_list"
    assert_includes gate, "def pending_for"
    assert_includes forces, "force_terms_acceptance"
    assert_includes forces, "Gate.pending_for"
    assert_includes users, "after_sign_up_path_for"
    assert_includes users, "Gate.after_auth_path"
    refute_includes forces, "Acceptance.create"
    refute_includes gate, "accepted?"
  end
end
