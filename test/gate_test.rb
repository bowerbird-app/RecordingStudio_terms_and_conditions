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
    assert RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("home", true))
    refute RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("home", false))
    refute RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("docs", false))
  end

  def test_gate_files_reuse_domain_helpers
    gate = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/gate.rb", __dir__))
    forces = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/forces_acceptance.rb", __dir__))
    users = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/users_auth_redirect.rb", __dir__))

    assert_includes gate, "requires_acceptance?"
    assert_includes forces, "force_terms_acceptance"
    assert_includes users, "after_sign_up_path_for"
    refute_includes forces, "Acceptance.create"
  end
end
