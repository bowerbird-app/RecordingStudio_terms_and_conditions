# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Host helper: drop the required Agree checkbox on a page or inside a host form.
  # Persistence stays on Acceptance via accept! / AcceptancesController.
  module AgreeHelper
    def recording_studio_terms_agree(inside_form: false, actor: nil, root: nil, link_terms: false)
      root ||= recording_studio_terms_agree_root
      terms = RecordingStudioTermsAndConditions.current_published_for(root)
      return if terms.blank?

      actor ||= recording_studio_terms_agree_actor
      return if actor.present? && RecordingStudioTermsAndConditions.accepted?(actor, root)

      recording_studio_terms_agree_fields(terms, inside_form, link_terms: link_terms)
    end

    private

    def recording_studio_terms_agree_fields(terms, _inside_form, link_terms: false)
      checkbox_id = "agreed_#{SecureRandom.hex(4)}"
      extras = link_terms ? [] : [recording_studio_terms_agree_full_terms_link(terms)]

      content_tag(:div, class: "py-5") do
        safe_join([
          recording_studio_terms_agree_labeled_box(terms, checkbox_id, link_terms),
          *extras
        ].compact)
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

    def recording_studio_terms_agree_full_terms_link(terms)
      url = terms.try(:published_url)
      return if url.blank?

      render(FlatPack::Link::Component.new(href: url).with_content("Read the full terms"))
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
