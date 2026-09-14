# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"

class AgreeHelperTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "helper-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Helper #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @recording = record_terms(@root, title: "Studio Terms", body: "Be kind. Don't be a jerk.")
    publish_terms!(@recording, slug: "helper-terms-#{SecureRandom.hex(4)}")
    sign_in @user
    switch_to_workspace(@workspace)
  end

  test "demo page stays reachable while the rest of the app is gated" do
    get "/"
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path

    get agree_helper_path
    assert_response :success
    assert_includes response.body, "Agree helper"
    assert_includes response.body, "On a page"
    assert_includes response.body, "Inside a form"
    assert_includes response.body, "I agree to these terms"
    assert_includes response.body, "Join"
    assert_select "input[type=checkbox][name=agreed][required]", count: 2
    assert_select "form[action=?]", recording_studio_terms_and_conditions.acceptance_path
    assert_select "form[action=?]", agree_helper_path
  end

  test "the in-form demo posts through accept!" do
    assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, 1 do
      post agree_helper_path, params: { agreed: "1", display_name: "Kit" }
    end

    assert_redirected_to agree_helper_path
    follow_redirect!
    assert_includes CGI.unescapeHTML(response.body), "You're in. Thanks for reading."
    assert RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
    assert_equal "clickwrap", RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last.provenance["source"]
  end

  test "the in-form demo stays gated on the server when the box is not ticked" do
    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      post agree_helper_path, params: { agreed: "0", display_name: "Kit" }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Tick the box if you agree."
    refute RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
  end
end
