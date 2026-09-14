# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"

class TermsGateTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "gate-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Gate #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @password = "Password"
    sign_in @user
    switch_to_workspace(@workspace)
  end

  test "unpublished workspace leaves home and docs free" do
    record_terms(@root, title: "Draft only", body: "Not live.")

    get root_path
    assert_response :success
    refute_redirected_to_acceptance

    get docs_install_path
    assert_response :success
  end

  test "published terms send signed-in people to the clickwrap" do
    publish_live_terms!

    get root_path
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path
    follow_redirect!
    assert_includes CGI.unescapeHTML(response.body), "One more thing — agree to the terms."
    assert_includes response.body, "I agree to these terms"
  end

  test "accepting the live version opens the app again" do
    publish_live_terms!
    get docs_install_path
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path

    post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "1" }

    assert_redirected_to docs_install_path
    follow_redirect!
    assert_response :success
    assert_includes CGI.unescapeHTML(response.body), "You're in. Thanks for reading."

    get root_path
    assert_response :success
  end

  test "a newly published version gates again" do
    recording = publish_live_terms!
    RecordingStudioTermsAndConditions.accept!(@user, recording, { "source" => "clickwrap" })

    get root_path
    assert_response :success

    revised = @root.revise(recording) { |terms| terms.body = "Be kinder." }
    publish_terms!(revised, slug: "gate-terms-#{SecureRandom.hex(4)}")

    get root_path
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path
    refute RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
  end

  test "devise sign in lands on agree when live terms require it" do
    ensure_default_workspace_requires_acceptance!
    sign_out @user

    post user_session_path, params: { user: { email: @user.email, password: @password } }

    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path
  end

  test "users auth after sign up uses the same clickwrap" do
    recording = publish_live_terms!
    controller = users_auth_controller_for(@workspace)

    assert_equal recording_studio_terms_and_conditions.acceptance_path, controller.after_sign_up_path_for(@user)
    assert_equal recording_studio_terms_and_conditions.acceptance_path, controller.after_sign_in_path_for(@user)

    RecordingStudioTermsAndConditions.accept!(@user, recording, { "source" => "clickwrap" })
    assert_equal "/after-auth", controller.after_sign_up_path_for(@user)
  end

  test "admin write and public terms stay reachable while the product is gated" do
    recording = publish_live_terms!
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_recording = RecordingStudio.root_recording_for(admin_root)
    unless RecordingStudioAccessible.authorized?(actor: @user, recording: admin_recording, role: :edit)
      bootstrap_owner_access!(@user, admin_recording)
    end

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success

    publishable = recording.publishable_child_recording
    get "/terms/#{publishable.id}/#{publishable.recordable.slug}"
    assert_response :success
  end

  private

  def ensure_default_workspace_requires_acceptance!
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    root = RecordingStudio.root_recording_for(workspace)
    return if RecordingStudioTermsAndConditions.requires_acceptance?(@user, workspace)

    recording = record_terms(root, title: "Studio Terms", body: "Be kind.")
    publish_terms!(recording, slug: "studio-terms-#{SecureRandom.hex(4)}")
  end

  def publish_live_terms!
    recording = record_terms(@root, title: "Gate Terms", body: "Be kind.")
    publish_terms!(recording, slug: "gate-terms-#{SecureRandom.hex(4)}")
    recording
  end

  def refute_redirected_to_acceptance
    refute_equal recording_studio_terms_and_conditions.acceptance_path, response.redirect_url.to_s.split("?").first
  end

  def users_auth_controller_for(workspace)
    Class.new do
      prepend RecordingStudioTermsAndConditions::UsersAuthRedirect

      def initialize(workspace)
        @workspace = workspace
      end

      def after_sign_in_path_for(_resource)
        "/after-auth"
      end

      def after_sign_up_path_for(_resource)
        "/after-auth"
      end

      def current_root_recordable
        @workspace
      end

      def recording_studio_terms_and_conditions
        Rails.application.routes.url_helpers.recording_studio_terms_and_conditions
      end
    end.new(workspace)
  end
end
