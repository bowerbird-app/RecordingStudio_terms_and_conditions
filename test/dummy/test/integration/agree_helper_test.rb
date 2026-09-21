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

    get "/agree_helper"
    assert_response :success
    assert_includes response.body, "Agree helper"
    assert_includes response.body, "recording_studio_terms_agree"
    assert_includes response.body, "recording_studio_terms_continue_notice"
    assert_includes response.body, "inside_form: true"
    assert_includes response.body, "link_terms: true"
    refute_includes response.body, "data-controller=\"recording-studio-terms-and-conditions--scroll-to-end\""
    assert_includes response.body, "I agree to these"
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree to Terms Dummy's"
    assert_select "a.flat-pack-link[href*='/terms/']", text: "terms"
    assert_select "a.flat-pack-link[data-modal-id]", text: "Terms & Conditions"
    assert_select "[data-controller='flat-pack--modal']", count: 1
    assert_includes response.body, "fp-content"
    refute_includes response.body, "Join"
    refute_includes response.body, "On a page"
    refute_includes response.body, "Inside a form"
    assert_select "input[type=checkbox][name=agreed][required]", count: 1
    assert_select "input[type=checkbox][name=agreed][checked]", count: 1
    assert_select "input[type=hidden][name=source][value=clickwrap]", count: 1
    assert_select "input[type=hidden][name=source][value=continue_notice]", count: 1
    assert_select "button", text: "Agree", count: 0
    assert_select "button", text: "Accept", count: 1
    assert_select "button", text: "Continue", count: 1
    assert_select "button", text: "Join", count: 0
    assert_select "form[action=?]", recording_studio_terms_and_conditions.acceptance_path, count: 0
    assert_select "form[action=?]", "/agree_helper", count: 2
  end

  test "continue notice POST writes a continue_notice receipt and clears the gate" do
    post "/agree_helper", params: { source: "continue_notice" }

    assert_redirected_to "/"
    follow_redirect!
    assert_response :success
    assert RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal({ "source" => "continue_notice" }, receipt.provenance)

    get "/"
    assert_response :success
  end

  test "checkbox POST writes a clickwrap receipt and clears the gate" do
    post "/agree_helper", params: { source: "clickwrap", agreed: "1" }

    assert_redirected_to "/"
    follow_redirect!
    assert_response :success
    assert RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal({ "source" => "clickwrap" }, receipt.provenance)

    get "/"
    assert_response :success
  end

  test "checkbox POST without a tick does not write a receipt" do
    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      post "/agree_helper", params: { source: "clickwrap", agreed: "0" }
    end

    assert_redirected_to "/agree_helper"
    refute RecordingStudioTermsAndConditions.accepted?(@user, @workspace)

    get "/"
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path
  end
end
