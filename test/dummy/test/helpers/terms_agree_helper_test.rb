# frozen_string_literal: true

require "test_helper"

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
end
