# frozen_string_literal: true

require "test_helper"
require "cgi"

class OmniauthGateTest < ActionDispatch::IntegrationTest
  setup do
    # This is the host that does not accept Terms during sign-up. The dummy
    # still registers SignupRegistration for the password screens.
    @registration_hooks = RecordingStudioUser.config.after_registration_hooks
    @removed_signup = @registration_hooks.delete(RecordingStudioTermsAndConditions::SignupRegistration)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    @original_create_account = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.omniauth_create_account = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    RecordingStudioUser.config.omniauth_create_account = @original_create_account
    if @removed_signup && !@registration_hooks.include?(@removed_signup)
      @registration_hooks << @removed_signup
    end
  end

  test "new Google user lands on the agree screen" do
    ensure_host_has_live_terms!
    email = "oauth-gate-#{SecureRandom.hex(4)}@example.com"
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-#{SecureRandom.hex(4)}",
      info: {
        email: email,
        name: "Gail OAuth",
        first_name: "Gail",
        last_name: "OAuth"
      }
    )

    get user_google_oauth2_omniauth_callback_path
    follow_redirects_until_html!

    assert_equal recording_studio_terms_and_conditions.acceptance_path, path_without_query
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    user = User.find_by!(email: email)
    studio = Workspace.find_by!(name: "Studio Workspace")
    refute RecordingStudioTermsAndConditions.pending_published_list(user).empty?
  end

  private

  def ensure_host_has_live_terms!
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    return if RecordingStudioTermsAndConditions.current_published_for.present?

    root = RecordingStudio.create_root_recording!(workspace, actor: recording_write_actor)
    recording = record_terms(root, title: "OAuth Terms", body: "Be kind.")
    publish_terms!(recording, slug: "oauth-terms-#{SecureRandom.hex(4)}")
  end

  def follow_redirects_until_html!
    5.times do
      break unless response.redirect?

      follow_redirect!
    end
    assert_response :success
  end

  def path_without_query
    URI.parse(request.original_url).path
  end
end
