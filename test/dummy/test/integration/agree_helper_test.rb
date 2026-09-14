# frozen_string_literal: true

require "test_helper"
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

    get "/agree_helper"
    assert_response :success
    assert_includes response.body, "Agree helper"
    assert_includes response.body, "recording_studio_terms_agree"
    assert_includes response.body, "inside_form: true"
    assert_includes response.body, "I agree to these terms"
    refute_includes response.body, "Join"
    refute_includes response.body, "On a page"
    refute_includes response.body, "Inside a form"
    assert_select "input[type=checkbox][name=agreed][required]", count: 1
    assert_select "button", text: "Agree", count: 0
    assert_select "button", text: "Join", count: 0
    assert_select "form[action=?]", recording_studio_terms_and_conditions.acceptance_path, count: 0
  end
end
