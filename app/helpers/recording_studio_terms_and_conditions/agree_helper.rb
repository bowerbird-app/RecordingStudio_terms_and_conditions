# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Host helper: drop the required Agree checkbox on a page or inside a host form.
  # Persistence stays on Acceptance via accept! / AcceptancesController.
  module AgreeHelper
    SCROLL_TO_END_CONTROLLER = "recording-studio-terms-and-conditions--scroll-to-end"

    def recording_studio_terms_agree(inside_form: false, actor: nil, root: nil, link_terms: false)
      root ||= recording_studio_terms_agree_root
      terms = RecordingStudioTermsAndConditions.current_published_for(root)
      return if terms.blank?

      actor ||= recording_studio_terms_agree_actor
      return if actor.present? && RecordingStudioTermsAndConditions.accepted?(actor, root)

      recording_studio_terms_agree_fields(terms, inside_form, link_terms: link_terms)
    end

    def recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: nil)
      if require_scroll_to_end.nil?
        RecordingStudioTermsAndConditions.configuration.require_scroll_to_end
      else
        ActiveModel::Type::Boolean.new.cast(require_scroll_to_end)
      end
    end

    def recording_studio_terms_scroll_to_end(require_scroll_to_end: nil, &block)
      html = capture(&block)
      return html unless recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: require_scroll_to_end)

      content_tag(:div, html, data: { controller: SCROLL_TO_END_CONTROLLER })
    end

    def recording_studio_terms_scroll_to_end_sentinel
      tag.span(
        "",
        "aria-hidden": true,
        data: { recording_studio_terms_and_conditions__scroll_to_end_target: "end" }
      )
    end

    def recording_studio_terms_agree_button(require_scroll_to_end: nil)
      scroll = recording_studio_terms_require_scroll_to_end?(require_scroll_to_end: require_scroll_to_end)
      arguments = { text: "Agree", style: :primary, type: "submit" }
      if scroll
        arguments[:disabled] = true
        arguments[:data] = { recording_studio_terms_and_conditions__scroll_to_end_target: "agree" }
      end

      render(FlatPack::Button::Component.new(**arguments))
    end

    private

    def recording_studio_terms_agree_fields(terms, _inside_form, link_terms: false)
      checkbox_id = "agreed_#{SecureRandom.hex(4)}"

      content_tag(:div, class: "py-5") do
        recording_studio_terms_agree_labeled_box(terms, checkbox_id, link_terms)
      end
    end

    def recording_studio_terms_agree_labeled_box(terms, checkbox_id, link_terms)
      checkbox = recording_studio_terms_agree_checkbox_tag(checkbox_id, link_terms)
      return checkbox unless link_terms

      content_tag(:div, class: "flex items-center") do
        safe_join([checkbox, recording_studio_terms_agree_linked_label(terms, checkbox_id)])
      end
    end

    def recording_studio_terms_agree_checkbox_tag(checkbox_id, link_terms)
      render(
        FlatPack::Checkbox::Component.new(
          **recording_studio_terms_agree_checkbox,
          id: checkbox_id,
          label: link_terms ? nil : "I agree to these terms"
        )
      )
    end

    def recording_studio_terms_agree_checkbox
      {
        name: "agreed",
        value: "1",
        checked: false,
        required: true
      }
    end

    def recording_studio_terms_agree_linked_label(terms, checkbox_id)
      label_tag(
        checkbox_id,
        safe_join(["I agree to these ".html_safe, recording_studio_terms_word_link(terms)]),
        class: "ml-[var(--checkbox-label-gap)] text-sm font-medium " \
               "text-[var(--surface-content-color)] cursor-pointer"
      )
    end

    def recording_studio_terms_word_link(terms)
      url = terms.try(:published_url)
      return "terms" if url.blank?

      render(FlatPack::Link::Component.new(href: url).with_content("terms"))
    end

    def recording_studio_terms_agree_root
      Gate.root_for(controller)
    end

    def recording_studio_terms_agree_actor
      return current_user if respond_to?(:current_user) && current_user

      Current.actor if defined?(Current)
    end
  end
end
