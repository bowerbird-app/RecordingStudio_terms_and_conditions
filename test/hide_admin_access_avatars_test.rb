# frozen_string_literal: true

require "test_helper"

class HideAdminAccessAvatarsTest < Minitest::Test
  class View
    include RecordingStudioTermsAndConditions::HideAdminAccessAvatars
  end

  def test_avatars_render_blank
    html = View.new.recording_studio_accessible_avatars(Object.new)

    assert_equal "", html
    assert_predicate html, :html_safe?
  end
end
