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
    assert_match(/privacy policy/, response.body)
    assert_includes response.body, '<p class="text-xs text-[var(--surface-muted-content-color)]">'
    assert_select "a.flat-pack-link[data-modal-id]", text: "Terms & Conditions"
    assert_select "a.flat-pack-link[data-modal-id]", text: "privacy policy"
    assert_includes response.body, "text-[var(--color-primary)]"
    assert_includes response.body, "underline"
    assert_includes response.body, "page-title"
    assert_includes response.body, "fp-content"
    refute_includes response.body, "--modal-title-color"
    live = RecordingStudioTermsAndConditions.current_published_for(@workspace)
    assert_includes response.body, live.title
    assert_includes CGI.unescapeHTML(response.body), live.body.to_s
  end

  test "create-password writes a continue_notice receipt and clears the gate" do
    email = "signup-accept-#{SecureRandom.hex(4)}@example.com"
    open_create_password(email)
    pending_count = RecordingStudioTermsAndConditions.pending_published_list(nil, @workspace).size

    assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, pending_count do
      post "/users/sign_up/password", params: {
        user: { email: email, password: "Password" }
      }
    end

    user = User.find_by!(email: email)
    assert RecordingStudioTermsAndConditions.accepted?(user, @workspace, kind: "terms_and_condition")
    assert RecordingStudioTermsAndConditions.accepted?(user, @workspace, kind: "privacy_policy") if pending_count > 1
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

  test "create-password falls back to a live-terms root when the current root has none" do
    empty = Workspace.create!(name: "Empty signup #{SecureRandom.hex(4)}")
    RecordingStudio.root_recording_for(empty)
    ensure_live_terms!
    live = RecordingStudioTermsAndConditions.current_published_for(@workspace)
    assert live

    email = "signup-fallback-#{SecureRandom.hex(4)}@example.com"

    with_current_root_for_gate(empty) do
      post "/users/sign_up", params: { user: { email: email } }
      assert_redirected_to "/users/sign_up/password"
      follow_redirect!

      assert_response :success
      assert_select "input#user_password[type=password]"
      assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
      assert_includes response.body, live.title
      pending_count = RecordingStudioTermsAndConditions.pending_published_list(nil, @workspace).size

      assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, pending_count do
        post "/users/sign_up/password", params: {
          user: { email: email, password: "Password" }
        }
      end
    end

    user = User.find_by!(email: email)
    assert RecordingStudioTermsAndConditions.accepted?(user, @workspace, kind: "terms_and_condition")
    refute RecordingStudioTermsAndConditions.current_published_for(empty)
    receipt = RecordingStudioTermsAndConditions::Acceptance.where(actor: user, terms_id: live.id).first
    assert receipt
    assert_equal({ "source" => "continue_notice" }, receipt.provenance)
    assert_equal user.id, receipt.actor_id
    assert_equal live.id, receipt.terms_id
  end

  private

  def ensure_live_terms!
    ensure_live_document!(
      kind: "terms_and_condition",
      title: "Signup Terms",
      body: "Be kind on the way in.",
      slug_prefix: "signup-terms"
    )
    ensure_live_document!(
      kind: "privacy_policy",
      title: "Signup Privacy",
      body: "We keep the version you agreed to.",
      slug_prefix: "signup-privacy"
    )
  end

  def ensure_live_document!(kind:, title:, body:, slug_prefix:)
    live = RecordingStudioTermsAndConditions.current_published_for(@workspace, kind: kind)
    return if live

    recording = record_terms(@root, title: title, body: body, kind: kind)
    publish_terms!(recording, slug: "#{slug_prefix}-#{SecureRandom.hex(4)}")
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

  def with_current_root_for_gate(root)
    gate = RecordingStudioTermsAndConditions::Gate
    gate.module_eval do
      alias_method :root_for_without_signup_fallback, :root_for
      define_method(:root_for) { |_controller| root }
    end
    yield
  ensure
    gate.module_eval do
      alias_method :root_for, :root_for_without_signup_fallback
      remove_method :root_for_without_signup_fallback
    end
  end
end
