# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Admin screens force compact widgets (number beside title). Terms widgets
  # always stack title above the count via the card variant.
  module AdminWidgetCard
    KEYS = %w[widgets.terms.live widgets.terms.agrees].freeze

    def render_recording_studio_widget(widget, variant: nil, link_policy: nil)
      super(widget, variant: stacked_card_variant(widget, variant), link_policy: link_policy)
    end

    def render_recording_studio_async_widget_frame(widget, parent:, parent_key:, variant: nil)
      super(
        widget,
        parent: parent,
        parent_key: parent_key,
        variant: stacked_card_variant(widget, variant)
      )
    end

    private

    def stacked_card_variant(widget, variant)
      return variant unless KEYS.include?(widget.key.to_s)

      :card
    end
  end
end
