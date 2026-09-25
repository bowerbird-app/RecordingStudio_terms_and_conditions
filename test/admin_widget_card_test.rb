# frozen_string_literal: true

require "test_helper"
require "recording_studio_terms_and_conditions/admin_widget_card"

class AdminWidgetCardTest < Minitest::Test
  class FakeHelper
    prepend RecordingStudioTermsAndConditions::AdminWidgetCard

    attr_reader :widget_variant, :frame_variant

    def render_recording_studio_widget(_widget, variant: nil, **)
      @widget_variant = variant
    end

    def render_recording_studio_async_widget_frame(_widget, variant: nil, **)
      @frame_variant = variant
    end
  end

  Widget = Struct.new(:key)

  def test_terms_widgets_stack_as_card_even_when_admin_asks_for_compact
    helper = FakeHelper.new
    helper.render_recording_studio_widget(Widget.new("widgets.terms.terms_agreed"), variant: :compact)
    helper.render_recording_studio_async_widget_frame(
      Widget.new("widgets.terms.privacy_agreed"),
      parent: :screen,
      parent_key: "recording_studio_terms",
      variant: :compact
    )

    assert_equal :card, helper.widget_variant
    assert_equal :card, helper.frame_variant
  end

  def test_other_admin_widgets_keep_the_requested_variant
    helper = FakeHelper.new
    helper.render_recording_studio_widget(Widget.new("widgets.users.total"), variant: :compact)

    assert_equal :compact, helper.widget_variant
  end
end
