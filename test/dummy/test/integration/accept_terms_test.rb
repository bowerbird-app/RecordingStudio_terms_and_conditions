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
    refute_select "header.fp-top-nav"
    assert_includes response.body, "Studio Terms"
    assert_includes response.body, "Be kind"
    assert_includes response.body, "I agree to these terms"
    assert_includes response.body, "flat-pack-content-editor-content"
    published_on = @recording.current_publishable.publish_at.in_time_zone.strftime("%e %b %Y").squish
    assert_includes response.body, published_on
    refute_includes response.body, "ago"
    refute_includes response.body, "Read the full terms"
    assert_select "div.py-5"
    assert_select "input[type=checkbox][name=agreed][required]"
    assert_select "input[type=checkbox][name=agreed][checked]", count: 0
    assert_includes response.body, "Agree"
    assert_select "[data-controller='recording-studio-terms-and-conditions--scroll-to-end']", count: 1
    assert_select "[data-recording-studio-terms-and-conditions--scroll-to-end-target='end']", count: 1
    assert_select "button[type=submit][disabled]", text: "Agree"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_match %r{flat_pack/application}, response.body
    refute_includes response.body, "Read them, tick the box"
    refute_includes response.body, "Tick the box if you agree."
    refute_includes response.body, "Terms updated"
    refute_includes CGI.unescapeHTML(response.body), "These terms changed. Agree again to stay in."
    refute_includes response.body, "Agree again"
  end

  test "re-gate after a new live version shows the updated notice and date" do
    RecordingStudioTermsAndConditions.accept!(@user, @recording, { "source" => "clickwrap" })
    revised = @root.revise(@recording) do |terms|
      terms.body = "Be kinder."
    end
    publish_terms!(revised, slug: "studio-terms-#{SecureRandom.hex(4)}")

    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert RecordingStudioTermsAndConditions.reaccepting?(@user, @workspace)
    refute RecordingStudioTermsAndConditions.accepted?(@user, @workspace)
    assert_includes response.body, "Terms updated"
    published_on = revised.current_publishable.publish_at.in_time_zone.strftime("%e %b %Y").squish
    assert_includes response.body, published_on
    assert_includes CGI.unescapeHTML(response.body), "You already agreed. This version is from #{published_on}."
    refute_includes response.body, "What changed"
    assert_select "button[type=submit]", text: "Agree again"
    refute_includes CGI.unescapeHTML(response.body), "The live version for this workspace."
    refute_includes CGI.unescapeHTML(response.body), "These terms changed. Agree again to stay in."
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
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal RecordingStudioTermsAndConditions::BodyDigest.call("Be kind. Don't be a jerk."), receipt.body_digest
    assert_equal({ "source" => "clickwrap" }, receipt.provenance)
    refute receipt.provenance.key?("ip")
    refute receipt.provenance.key?("user_agent")
  end

  test "double agree for the same live snapshot does not insert a second receipt" do
    post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "1" }
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last

    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "1" }
    end

    assert_redirected_to "/"
    assert_equal receipt.id, RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last.id
    assert_equal receipt.body_digest, receipt.reload.body_digest
  end

  test "gem UI stores IP and user agent only when capture_request_provenance is on" do
    RecordingStudioTermsAndConditions.configuration.capture_request_provenance = true

    post recording_studio_terms_and_conditions.acceptance_path,
         params: { agreed: "1" },
         headers: { "User-Agent" => "TermsTest/1.0" }

    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal "clickwrap", receipt.provenance.fetch("source")
    assert receipt.provenance["ip"].present?
    assert_equal "TermsTest/1.0", receipt.provenance.fetch("user_agent")
  ensure
    RecordingStudioTermsAndConditions.configuration.capture_request_provenance = false
  end

  test "agree stays enabled when the host leaves scroll-to-end off" do
    RecordingStudioTermsAndConditions.configuration.require_scroll_to_end = false

    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_select "[data-controller='recording-studio-terms-and-conditions--scroll-to-end']", count: 0
    assert_select "[data-recording-studio-terms-and-conditions--scroll-to-end-target='end']", count: 0
    assert_select "button[type=submit][disabled]", text: "Agree", count: 0
    assert_select "button[type=submit]", text: "Agree"
    assert_select "input[type=checkbox][name=agreed][required]"
  ensure
    RecordingStudioTermsAndConditions.configuration.require_scroll_to_end = true
  end

  test "empty state when the current workspace has no live terms" do
    empty = Workspace.create!(name: "Empty #{SecureRandom.hex(4)}")
    switch_to_workspace(empty)

    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_includes response.body, "Nothing to agree to yet"
  end

  test "agreeing when the workspace only has a draft does not write a receipt" do
    draft_workspace = Workspace.create!(name: "Draft #{SecureRandom.hex(4)}")
    draft_root = RecordingStudio.root_recording_for(draft_workspace)
    record_terms(draft_root, title: "Draft terms", body: "Not live.")
    switch_to_workspace(draft_workspace)

    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "1" }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "There are no live terms to agree to."
  end

  test "agreeing to a non-live version does not write a receipt" do
    draft = record_terms(@root, title: "Stale draft", body: "Skip me.")
    force_current_published_for(draft.recordable) do
      assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
        post recording_studio_terms_and_conditions.acceptance_path, params: { agreed: "1" }
      end
    end

    assert_response :unprocessable_entity
    assert_includes CGI.unescapeHTML(response.body), "Those terms aren't live. Refresh and agree to the current ones."
  end

  private

  def force_current_published_for(terms)
    mod = RecordingStudioTermsAndConditions.singleton_class
    mod.class_eval do
      alias_method :current_published_for_without_a3, :current_published_for
      alias_method :pending_published_for_without_a3, :pending_published_for
      alias_method :pending_published_list_without_a3, :pending_published_list
      define_method(:current_published_for) { |*_args, **_kwargs| terms }
      define_method(:pending_published_for) { |*_args, **_kwargs| terms }
      define_method(:pending_published_list) { |*_args, **_kwargs| Array(terms).compact }
    end
    yield
  ensure
    mod.class_eval do
      alias_method :current_published_for, :current_published_for_without_a3
      alias_method :pending_published_for, :pending_published_for_without_a3
      alias_method :pending_published_list, :pending_published_list_without_a3
      remove_method :current_published_for_without_a3
      remove_method :pending_published_for_without_a3
      remove_method :pending_published_list_without_a3
    end
  end
end
