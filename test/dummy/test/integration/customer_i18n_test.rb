# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"

class CustomerI18nTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @root = RecordingStudio.root_recording_for(@workspace)
    ensure_live_terms!
  end

  test "language selector sits in the dummy page nav" do
    sign_in @user
    accept_pending_live_terms!(@user)
    get "/"

    assert_response :success
    assert_select "form[action='/recording_studio_internationalization/locale']"
    assert_includes response.body, "English"
    assert_includes response.body, "Français"
    assert_select "html[lang='en']"
    assert_includes response.body, "dummy-language-selector"
    refute_select "header.fp-top-nav"
  end

  test "accept page, signup notice and checkbox stay English by default" do
    visitor = fresh_user
    sign_in visitor
    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_select "h1", text: /Terms and Conditions/
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_select "button", text: "Continue"
    assert_select "html[lang='en']"

    sign_out visitor
    email = "signup-en-#{SecureRandom.hex(4)}@example.com"
    post "/users/sign_up", params: { user: { email: email } }
    follow_redirect!

    assert_response :success
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_select "button[type=button][data-modal-id]", text: "Terms & Conditions"

    sign_in @user
    accept_pending_live_terms!(@user)
    get "/agree_helper"

    assert_response :success
    assert_includes response.body, "I agree to these"
    assert_select "a.flat-pack-link", text: "terms"
  end

  test "dummy French locale renders accept page, signup notice and checkbox" do
    visitor = fresh_user
    sign_in visitor
    switch_to_french
    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_select "h1", text: /Conditions générales/
    assert_includes CGI.unescapeHTML(response.body), "En continuant, vous acceptez"
    assert_includes CGI.unescapeHTML(response.body), "les conditions générales"
    assert_includes CGI.unescapeHTML(response.body), "la politique de confidentialité"
    assert_select "button", text: "Continuer"
    refute_includes response.body, "We have updated our terms and conditions."
    refute_select "button", text: "Continue"
    assert_select "html[lang='fr']"

    sign_out visitor
    email = "signup-fr-#{SecureRandom.hex(4)}@example.com"
    post "/users/sign_up", params: { user: { email: email } }
    follow_redirect!

    assert_response :success
    assert_includes CGI.unescapeHTML(response.body), "En continuant, vous acceptez"
    assert_includes CGI.unescapeHTML(response.body), "les conditions générales"
    assert_includes CGI.unescapeHTML(response.body), "la politique de confidentialité"
    assert_select "button[type=button][data-modal-id]", text: "les conditions générales"
    refute_includes CGI.unescapeHTML(response.body), "By continuing, you agree"

    sign_in @user
    accept_pending_live_terms!(@user)
    get "/agree_helper"

    assert_response :success
    assert_includes CGI.unescapeHTML(response.body), "J’accepte"
    assert_select "a.flat-pack-link", text: "les conditions générales"
    assert_select "a.flat-pack-link", text: "la politique de confidentialité"
    assert_select "button", text: "Accepter"
    assert_select "button", text: "Continuer"
    refute_select "button", text: "Accept"
    refute_includes response.body, "I agree to these"
    refute_includes response.body, "J’accepte ces conditions"
  end

  test "checkbox validation error follows the locale" do
    sign_in @user
    post "/agree_helper", params: { source: "clickwrap", agreed: "0" }
    follow_redirect!

    assert_includes response.body, "Tick the box if you agree."

    switch_to_french
    post "/agree_helper", params: { source: "clickwrap", agreed: "0" }
    follow_redirect!

    assert_includes response.body, "Cochez la case si vous acceptez."
    refute_includes response.body, "Tick the box if you agree."
  end

  private

  def switch_to_french
    patch "/recording_studio_internationalization/locale", params: { locale: "fr", return_to: "/" }
    follow_redirect! if response.redirect?
  end

  def ensure_live_terms!
    ensure_live_kind!(
      RecordingStudioTermsAndConditions::Terms::KIND_TERMS,
      title: "Terms and Conditions v1.0",
      body: "Be kind in the booth.",
      slug_prefix: "i18n-terms"
    )
    ensure_live_kind!(
      RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY,
      title: "Privacy Policy v1.0",
      body: "We keep a receipt of when you agreed.",
      slug_prefix: "i18n-privacy"
    )
  end

  def ensure_live_kind!(kind, title:, body:, slug_prefix:)
    return if RecordingStudioTermsAndConditions.current_published_for(@workspace, kind: kind)

    recording = record_terms(@root, title: title, body: body, kind: kind)
    publish_terms!(recording, slug: "#{slug_prefix}-#{SecureRandom.hex(4)}")
  end

  def fresh_user
    User.create!(
      email: "i18n-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  def accept_pending_live_terms!(user)
    RecordingStudioTermsAndConditions.pending_published_list(user, @workspace).each do |terms|
      RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "continue_notice" })
    end
  end
end
