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
    RecordingStudioTermsAndConditions.configuration.require_scroll_to_end = false
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

  test "agree button stays enabled in HTML when scroll-to-end is on" do
    html = recording_studio_terms_agree_button(require_scroll_to_end: true)

    refute_includes html, "disabled=\"disabled\""
    refute_match(/<button[^>]*\sdisabled(?:=|>|\s)/, html)
    assert_includes html, "recording-studio-terms-and-conditions--scroll-to-end-target"
  end

  test "agree button is Flatpack primary for Accept Continue" do
    html = recording_studio_terms_agree_button(require_scroll_to_end: false, text: "Continue")

    assert_includes html, 'data-fp-style="primary"'
    assert_includes html, "fp-button"
    assert_includes html, "fp-button-raised"
    assert_includes html, "<span>Continue</span>"
    refute_includes html, 'data-fp-style="secondary"'
    refute_includes html, 'data-fp-style="ghost"'
    refute_includes html, "fp-button-flat"
  end

  test "scroll sentinel has a box so IntersectionObserver can see it" do
    html = recording_studio_terms_scroll_to_end_sentinel

    assert_includes html, "block h-px w-full"
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
    assert_includes html, "page-title"
    refute_includes html, "--modal-title-color"
    assert_includes html, "flat-pack-link"
    assert_includes html, "text-[var(--color-primary)]"
    assert_includes html, "underline"
    assert_includes html, '<p class="text-xs text-[var(--surface-muted-content-color)]">'
    refute_includes html, "text-sm text-[var(--surface-muted-content-color)]"
  end

  test "continue notice size sm uses text-sm and stays muted" do
    terms = Struct.new(:body, :title).new("<p>Be kind.</p>", "Studio Terms")

    html = recording_studio_terms_continue_notice(pending: [terms], size: :sm)

    assert_includes html, '<p class="text-sm text-[var(--surface-muted-content-color)]">'
    refute_includes html, "text-xs text-[var(--surface-muted-content-color)]"
  end

  test "continue notice unknown sizes fall back to xs" do
    terms = Struct.new(:body, :title).new("<p>Be kind.</p>", "Studio Terms")

    assert_includes recording_studio_terms_continue_notice(pending: [terms], size: :lg),
                    '<p class="text-xs text-[var(--surface-muted-content-color)]">'
  end

  test "accept page title names the update from pending kinds" do
    terms = Struct.new(:title, :kind).new("Studio Terms", "terms_and_condition")
    privacy = Struct.new(:title, :kind).new("Studio Privacy", "privacy_policy")
    def terms.terms_and_condition? = true
    def terms.privacy_policy? = false
    def privacy.terms_and_condition? = false
    def privacy.privacy_policy? = true

    assert_equal "We have updated our terms and conditions.",
                 terms_accept_page_title(terms, pending: [terms])
    assert_equal "We have updated our privacy policy.",
                 terms_accept_page_title(privacy, pending: [privacy])
    assert_equal "We have updated our terms and conditions and privacy policy.",
                 terms_accept_page_title(terms, pending: [terms, privacy])
    assert_equal "We have updated our terms and conditions.",
                 terms_accept_page_title(nil)
  end

  test "continue notice wraps with vertical spacing" do
    terms = Struct.new(:body, :title).new("<p>Be kind in the booth.</p>", "Studio Terms")

    html = recording_studio_terms_continue_notice(pending: [terms])

    assert_includes html, 'class="my-3"'
  end

  test "continue notice link false is plain text without a modal" do
    terms = Struct.new(:body, :title).new("<p>Be kind in the booth.</p>", "Studio Terms")
    privacy = Struct.new(:body, :title, :kind).new(
      "<p>Private.</p>",
      "Studio Privacy",
      "privacy_policy"
    )
    def privacy.terms_and_condition? = false
    def privacy.privacy_policy? = true

    html = recording_studio_terms_continue_notice(pending: [terms, privacy], link: false)

    assert_includes CGI.unescapeHTML(html), "By continuing, you agree to Terms Dummy's"
    assert_includes html, "Terms &amp; Conditions"
    assert_includes html, "privacy policy"
    assert_includes html, 'class="my-3"'
    assert_includes html, '<p class="text-xs text-[var(--surface-muted-content-color)]">'
    refute_includes html, "data-modal-id"
    refute_includes html, "flat-pack--modal"
    refute_includes html, "flat-pack-link"
    refute_includes html, "fp-content"
    refute_includes html, "Be kind in the booth."
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

  test "continue notice includes privacy copy and modal when privacy is pending" do
    terms = Struct.new(:body, :title, :kind).new(
      "<p>Be kind.</p>",
      "Studio Terms",
      "terms_and_condition"
    )
    privacy = Struct.new(:body, :title, :kind).new(
      "<p>We keep receipts.</p>",
      "Studio Privacy",
      "privacy_policy"
    )
    def terms.terms_and_condition? = true
    def terms.privacy_policy? = false
    def privacy.terms_and_condition? = false
    def privacy.privacy_policy? = true

    html = recording_studio_terms_continue_notice(pending: [terms, privacy])

    assert_match(/and <a[^>]*>privacy policy<\/a>/, html)
    assert_includes html, "Terms &amp; Conditions"
    assert_equal 2, html.scan('data-controller="flat-pack--modal"').size
    assert_includes html, "We keep receipts"
  end

  test "agree checkbox includes privacy link with target blank" do
    terms = Struct.new(:body, :title, :published_url).new(
      "<p>Be kind.</p>",
      "Studio Terms",
      "/terms/1/studio"
    )
    privacy = Struct.new(:body, :title, :published_url).new(
      "<p>Private.</p>",
      "Studio Privacy",
      "/privacy/2/studio"
    )
    def terms.terms_and_condition? = true
    def terms.privacy_policy? = false
    def privacy.terms_and_condition? = false
    def privacy.privacy_policy? = true

    html = recording_studio_terms_agree(pending: [terms, privacy], link_terms: true)

    assert_includes html, "I agree to these"
    assert_includes html, 'href="/terms/1/studio"'
    assert_includes html, 'href="/privacy/2/studio"'
    assert_includes html, 'target="_blank"'
    assert_includes html, "privacy policy"
  end
end
