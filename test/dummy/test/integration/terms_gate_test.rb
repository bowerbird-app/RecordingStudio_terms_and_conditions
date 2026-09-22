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

    get "/"
    assert_response :success
    refute_redirected_to_acceptance

    get "/docs/install"
    assert_response :success
  end

  test "published terms send signed-in people to the clickwrap" do
    publish_live_terms!

    get "/"
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path
    follow_redirect!
    refute_includes CGI.unescapeHTML(response.body), "One more thing — agree to the terms."
    refute_includes response.body, "One more thing"
    assert_includes response.body, "I agree to these terms"
  end

  test "accepting the live version opens the app again" do
    publish_live_terms!
    get "/docs/install"
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path

    post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "1" }

    assert_redirected_to "/docs/install"
    follow_redirect!
    assert_response :success
    refute_includes CGI.unescapeHTML(response.body), "You're in. Thanks for reading."
    refute_includes response.body, "You're in"

    get "/"
    assert_response :success
  end

  test "a newly published version gates again" do
    recording = publish_live_terms!
    RecordingStudioTermsAndConditions.accept!(@user, recording, { "source" => "clickwrap" })

    get "/"
    assert_response :success

    revised = @root.revise(recording) { |terms| terms.body = "Be kinder." }
    publish_terms!(revised, slug: "gate-terms-#{SecureRandom.hex(4)}")

    get "/"
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path
    follow_redirect!
    assert_includes CGI.unescapeHTML(response.body), "We've updated our Terms and Conditions"
    refute_includes response.body, "Terms updated"
    refute RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
    assert RecordingStudioTermsAndConditions.reaccepting?(@user, @workspace)
  end

  test "users auth sign in lands on agree when live terms require it" do
    studio = Workspace.find_or_create_by!(name: "Studio Workspace")
    RecordingStudio.root_recording_for(studio)
    ensure_default_workspace_requires_acceptance!
    switch_to_workspace(studio)
    sign_out @user

    post "/users/sign_in", params: { user: { email: @user.email } }
    assert_redirected_to "/users/sign_in/password"
    follow_redirect!
    post "/users/sign_in/password", params: { user: { email: @user.email, password: @password } }

    assert_response :redirect
    follow_redirect!
    follow_redirect! if response.redirect?
    assert_includes response.body, "I agree to these terms"
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

    switch_to_workspace(admin_root)
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
    agree_path = recording_studio_terms_and_conditions.acceptance_path
    Class.new do
      prepend RecordingStudioTermsAndConditions::UsersAuthRedirect

      def initialize(workspace, agree_path)
        @workspace = workspace
        @agree_path = agree_path
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
        Struct.new(:acceptance_path).new(@agree_path)
      end
    end.new(workspace, agree_path)
  end
end
