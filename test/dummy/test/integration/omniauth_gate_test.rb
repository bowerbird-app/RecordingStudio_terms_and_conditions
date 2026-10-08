# frozen_string_literal: true

require "test_helper"
require "cgi"

class OmniauthGateTest < ActionDispatch::IntegrationTest
  setup do
    skip "OmniAuth Google callback is not wired in this dummy app" unless omniauth_google_callback?
    skip "OmniAuth is not loaded" unless defined?(OmniAuth)

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    @original_create_account = RecordingStudioUser.config.omniauth_create_account if defined?(RecordingStudioUser)
    RecordingStudioUser.config.omniauth_create_account = true if defined?(RecordingStudioUser)
  end

  teardown do
    if defined?(OmniAuth)
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end
    RecordingStudioUser.config.omniauth_create_account = @original_create_account if defined?(RecordingStudioUser)
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
    refute RecordingStudioTermsAndConditions.pending_published_list(
      user,
      RecordingStudioTermsAndConditions::Gate.first_root_with_live_terms
    ).empty?
  end

  private

  def omniauth_google_callback?
    Rails.application.routes.recognize_path("/users/auth/google_oauth2/callback", method: :get)
    true
  rescue ActionController::RoutingError
    false
  end

  def ensure_host_has_live_terms!
    return if RecordingStudioTermsAndConditions::Gate.first_root_with_live_terms.present?

    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    root = RecordingStudio.root_recording_for(workspace)
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
