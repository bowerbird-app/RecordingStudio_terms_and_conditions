# frozen_string_literal: true

require "test_helper"
require "cgi"

class TermsAgreeHelperTest < ActionView::TestCase
  include RecordingStudioTermsAndConditions::ApplicationHelper

  test "helper option turns scroll-to-end on when config is off" do
    RecordingStudioTermsAndConditions.configuration.require_scroll_to_end = false

    refute recording_studio_terms_require_scroll_to_end?
    assert recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: true)
    refute recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: false)
  ensure
    RecordingStudioTermsAndConditions.configuration.require_scroll_to_end = true
  end

  test "scroll wrap is a no-op when the option is off" do
    html = recording_studio_terms_scroll_to_end(require_scroll_to_end: false) { "copy" }

    assert_equal "copy", html
  end

  test "scroll wrap adds the stimulus controller when the option is on" do
    html = recording_studio_terms_scroll_to_end(require_scroll_to_end: true) { "copy" }

    assert_includes html, 'data-controller="recording-studio-terms-and-conditions--scroll-to-end"'
    assert_includes html, "copy"
  end

  test "agree button starts disabled when scroll-to-end is on so JS can unlock" do
    html = recording_studio_terms_agree_button(require_scroll_to_end: true)

    assert_includes html, "disabled"
    assert_includes html, "recording-studio-terms-and-conditions--scroll-to-end-target"
  end

  test "terms copy wraps in Flatpack Content" do
    html = terms_content("<p>Be kind in the booth.</p>")

    assert_includes html, "fp-content"
    assert_includes html, "Be kind in the booth."
    refute_includes html, "flat-pack-content-editor-content"
  end

  test "continue notice names the app and opens a Content modal" do
    terms = Struct.new(:body, :title).new("<p>Be kind in the booth.</p>", "Studio Terms")

    html = recording_studio_terms_continue_notice(pending: [terms])

    assert_includes CGI.unescapeHTML(html), "By continuing, you agree to Terms Dummy's"
    assert_includes html, "Terms &amp; Conditions"
    assert_includes html, "data-modal-id"
    assert_includes html, "data-controller=\"flat-pack--modal\""
    assert_includes html, "fp-content"
    assert_includes html, "Be kind in the booth."
    assert_includes html, "Studio Terms"
  end

  test "continue notice drops the possessive when app_name is blank" do
    RecordingStudioTermsAndConditions.configuration.app_name = ""
    terms = Struct.new(:body, :title).new("<p>Be kind.</p>", "Studio Terms")

    html = recording_studio_terms_continue_notice(pending: [terms])

    assert_includes html, "By continuing, you agree to the "
    refute_includes html, "'s Terms"
  ensure
    RecordingStudioTermsAndConditions.configuration.app_name = "Terms Dummy"
  end
end
