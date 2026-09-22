# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Optional clickwrap gate: Agree stays disabled until the end sentinel is visible.
  # Hosts opt in with `config.require_scroll_to_end` or a helper keyword.
  # A closed collapse hides the sentinel, so Agree stays enabled until the copy can be
  # scrolled. Missing IntersectionObserver leaves Agree enabled.
  module ScrollToEndHelper
    SCROLL_TO_END_CONTROLLER = "recording-studio-terms-and-conditions--scroll-to-end"

    def recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: nil)
      if require_scroll_to_end.nil?
        RecordingStudioTermsAndConditions.configuration.require_scroll_to_end
      else
        RecordingStudioTermsAndConditions::Configuration.flag?(require_scroll_to_end)
      end
    end

    def recording_studio_terms_scroll_to_end(require_scroll_to_end: nil, &)
      html = capture(&)
      return html unless recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: require_scroll_to_end)

      content_tag(:div, html, data: { controller: SCROLL_TO_END_CONTROLLER })
    end

    def recording_studio_terms_scroll_to_end_sentinel
      tag.span(
        "",
        "aria-hidden": true,
        class: "block h-px w-full",
        data: { recording_studio_terms_and_conditions__scroll_to_end_target: "end" }
      )
    end

    def recording_studio_terms_agree_button(require_scroll_to_end: nil, text: "Agree")
      scroll = recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: require_scroll_to_end)
      arguments = { text: text, style: :primary, type: "submit" }
      if scroll
        arguments[:data] = { recording_studio_terms_and_conditions__scroll_to_end_target: "agree" }
      end

      render(FlatPack::Button::Component.new(**arguments))
    end
  end
end
