# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"

class AcceptTermsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "agree-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Agree #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @recording = record_terms(@root, title: "Studio Terms", body: "Be kind. Don't be a jerk.")
    publish_terms!(@recording, slug: "studio-terms-#{SecureRandom.hex(4)}")
    sign_in @user
    switch_to_workspace(@workspace)
  end

  test "clickwrap shows live terms with an unchecked required checkbox" do
    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_includes response.body, "Studio Terms"
    assert_includes response.body, "Be kind"
    assert_includes response.body, "I agree to these terms"
    assert_includes response.body, "flat-pack-content-editor-content"
    assert_select "time.flat-pack-timestamp"
    assert_select "div.py-5"
    assert_select "input[type=checkbox][name=agreed][required]"
    assert_select "input[type=checkbox][name=agreed][checked]", count: 0
    assert_includes response.body, "Agree"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_match %r{flat_pack/application}, response.body
    refute_includes response.body, "Read them, tick the box"
    refute_includes response.body, "Tick the box if you agree."
  end

  test "agree stays gated on the server when the box is not ticked" do
    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "0" }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Tick the box if you agree."
    refute RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
  end

  test "ticking agree records a clickwrap receipt" do
    post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "1" }

    assert_redirected_to "/"
    follow_redirect!
    assert_includes CGI.unescapeHTML(response.body), "You're in. Thanks for reading."
    assert RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
  end

  test "empty state when the current workspace has no live terms" do
    empty = Workspace.create!(name: "Empty #{SecureRandom.hex(4)}")
    switch_to_workspace(empty)

    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_includes response.body, "Nothing to agree to yet"
  end
end
