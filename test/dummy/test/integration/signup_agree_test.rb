# frozen_string_literal: true

require "test_helper"
require "cgi"

class SignupAgreeTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @root = RecordingStudio.root_recording_for(@workspace)
    ensure_live_terms!
  end

  test "create-password shows the continue notice in extra_fields when terms are pending" do
    email = "signup-notice-#{SecureRandom.hex(4)}@example.com"

    post "/users/sign_up", params: { user: { email: email } }
    assert_redirected_to "/users/sign_up/password"
    follow_redirect!

    assert_response :success
    assert_select "input#user_password[type=password]"
    assert_select "button[type=submit]", text: "Sign up"
    assert_select "input[type=checkbox][name=agreed]", count: 0
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_includes response.body, "Terms &amp; Conditions"
    assert_includes response.body, '<p class="text-xs text-[var(--surface-muted-content-color)]">'
    assert_select "a.flat-pack-link[data-modal-id]", text: "Terms & Conditions"
    assert_includes response.body, "text-[var(--color-primary)]"
    assert_includes response.body, "underline"
    assert_includes response.body, "page-title"
    assert_includes response.body, "fp-content"
    live = RecordingStudioTermsAndConditions.current_published_for(@workspace)
    assert_includes response.body, live.title
    assert_includes CGI.unescapeHTML(response.body), live.body.to_s
  end

  test "create-password writes a continue_notice receipt and clears the gate" do
    email = "signup-accept-#{SecureRandom.hex(4)}@example.com"
    open_create_password(email)

    assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, +1 do
      post "/users/sign_up/password", params: {
        user: { email: email, password: "Password" }
      }
    end

    user = User.find_by!(email: email)
    assert RecordingStudioTermsAndConditions.accepted?(user, @workspace)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal({ "source" => "continue_notice" }, receipt.provenance)
    assert_equal user.id, receipt.actor_id

    follow_redirect!
    follow_redirect! if response.redirect?
    get "/"
    assert_response :success
    refute_equal recording_studio_terms_and_conditions.acceptance_path, response.redirect_url.to_s.split("?").first
  end

  test "create-password stays blank when the current workspace has no live terms" do
    empty_pending_published_list do
      email = "signup-empty-#{SecureRandom.hex(4)}@example.com"
      post "/users/sign_up", params: { user: { email: email } }
      follow_redirect!

      assert_response :success
      assert_select "input#user_password[type=password]"
      assert_select "input[type=checkbox][name=agreed]", count: 0
      refute_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    end
  end

  private

  def ensure_live_terms!
    return if RecordingStudioTermsAndConditions.current_published_for(@workspace)

    recording = record_terms(@root, title: "Signup Terms", body: "Be kind on the way in.")
    publish_terms!(recording, slug: "signup-terms-#{SecureRandom.hex(4)}")
  end

  def open_create_password(email)
    post "/users/sign_up", params: { user: { email: email } }
    assert_redirected_to "/users/sign_up/password"
    follow_redirect!
    assert_response :success
  end

  def empty_pending_published_list
    mod = RecordingStudioTermsAndConditions.singleton_class
    mod.class_eval do
      alias_method :pending_published_list_without_signup, :pending_published_list
      define_method(:pending_published_list) { |*_args, **_kwargs| [] }
    end
    yield
  ensure
    mod.class_eval do
      alias_method :pending_published_list, :pending_published_list_without_signup
      remove_method :pending_published_list_without_signup
    end
  end
end
