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
      checkbox = render(
        FlatPack::Checkbox::Component.new(
          **recording_studio_terms_agree_checkbox,
          id: checkbox_id,
          label: link_terms ? nil : "I agree to these terms"
        )
      )
      labeled = if link_terms
                  content_tag(:div, class: "flex items-center") do
                    safe_join([checkbox, recording_studio_terms_agree_linked_label(terms, checkbox_id)].compact)
                  end
                else
                  checkbox
                end

      extras = link_terms ? [] : [recording_studio_terms_agree_full_terms_link(terms)]
      content_tag(:div, class: "py-5") do
        safe_join([labeled, *extras].compact)
      end
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
      url = terms.try(:published_url)
      terms_word = if url.present?
                     render(FlatPack::Link::Component.new(href: url) { "terms" })
                   else
                     "terms"
                   end

      label_tag(
        checkbox_id,
        safe_join(["I agree to these ".html_safe, terms_word]),
        class: "ml-[var(--checkbox-label-gap)] text-sm font-medium text-[var(--surface-content-color)] cursor-pointer"
      )
    end

    def recording_studio_terms_agree_full_terms_link(terms)
      url = terms.try(:published_url)
      return if url.blank?

      render(FlatPack::Link::Component.new(href: url) { "Read the full terms" })
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
