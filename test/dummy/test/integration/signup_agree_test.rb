# frozen_string_literal: true

require "test_helper"
require "cgi"

class SignupAgreeTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: recording_write_actor)
    ensure_live_terms!
  end

  test "signup notice renders beside the button only when live terms exist" do
    email = "signup-notice-#{SecureRandom.hex(4)}@example.com"

    post "/users/sign_up", params: { user: { email: email } }
    assert_redirected_to "/users/sign_up/password"
    follow_redirect!

    assert_response :success
    assert_select "input#user_password[type=password]"
    assert_select 'button[type=submit][data-fp-style="primary"]', text: "Sign up"
    assert_match %r{flat_pack/application}, response.body
    assert_select "input[type=checkbox][name=agreed]", count: 0
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_includes response.body, "Terms &amp; Conditions"
    assert_match(/privacy policy/, response.body)
    assert_includes response.body, '<p class="text-xs text-[var(--surface-muted-content-color)]">'
    assert_select "div.mt-3.mb-3"
    assert_select "div.mt-3.mb-6", count: 0
    assert_select "button[type=button][data-modal-id]", text: "Terms & Conditions"
    assert_select "button[type=button][data-modal-id]", text: "privacy policy"
    css_select("button[type=button][data-modal-id]").each do |button|
      assert_nil button["href"]
      assert_select "[id=?]", button["data-modal-id"]
    end
    assert_includes response.body, "text-[var(--color-primary)]"
    assert_includes response.body, "underline"
    assert_includes response.body, "page-title"
    assert_includes response.body, "fp-content"
    refute_includes response.body, "--modal-title-color"
    live = RecordingStudioTermsAndConditions.current_published_for
    assert_includes response.body, live.title
    assert_includes CGI.unescapeHTML(response.body), live.body.to_s
  end

  test "signup hook accepts pending live terms for password oauth and otp" do
    %i[password oauth otp].each do |method|
      user = User.create!(
        email: "signup-#{method}-#{SecureRandom.hex(4)}@example.com",
        password: "Password",
        password_confirmation: "Password"
      )
      pending = RecordingStudioTermsAndConditions.pending_published_list(user)
      assert_predicate pending, :any?

      assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.where(actor: user).count }, pending.size do
        RecordingStudioTermsAndConditions::SignupRegistration.call(user: user, method: method)
      end

      pending.each do |terms|
        receipt = RecordingStudioTermsAndConditions::Acceptance.find_by!(actor: user, terms_id: terms.id)
        assert_equal({ "source" => "signup", "method" => method.to_s }, receipt.provenance)
        assert_equal RecordingStudioTermsAndConditions::BodyDigest.call(terms.body), receipt.body_digest
        assert RecordingStudioTermsAndConditions.accepted?(user, kind: terms.kind)
      end
      refute RecordingStudioTermsAndConditions.requires_acceptance?(user)
    end
  end

  test "signup notice stays blank when nothing is live" do
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
    live = RecordingStudioTermsAndConditions.current_published_for(kind: kind)
    return if live

    recording = record_terms(@root, title: title, body: body, kind: kind)
    publish_terms!(recording, slug: "#{slug_prefix}-#{SecureRandom.hex(4)}")
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
