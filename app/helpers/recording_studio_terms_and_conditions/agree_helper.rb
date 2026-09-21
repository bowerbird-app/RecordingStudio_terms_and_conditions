# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Host helper: drop the required Agree checkbox on a page or inside a host form.
  # Persistence stays on Acceptance via accept! / AcceptancesController.
  module AgreeHelper
    include ScrollToEndHelper
    include AgreeCopyHelper
    include TermsContextHelper

    def recording_studio_terms_agree(inside_form: false, actor: nil, root: nil, link_terms: false, pending: nil)
      root ||= recording_studio_terms_agree_root
      actor ||= recording_studio_terms_agree_actor
      pending_terms = recording_studio_terms_pending_list(actor, root, pending)
      return if pending.nil? && actor.present? &&
                !RecordingStudioTermsAndConditions.requires_acceptance?(actor, root)
      return if pending_terms.blank?

      recording_studio_terms_agree_fields(pending_terms, inside_form, link_terms: link_terms)
    end

    private

    def recording_studio_terms_agree_fields(terms_list, _inside_form, link_terms: false)
      checkbox_id = "agreed_#{SecureRandom.hex(4)}"

      content_tag(:div, class: "py-5") do
        recording_studio_terms_agree_labeled_box(terms_list, checkbox_id, link_terms)
      end
    end

    def recording_studio_terms_agree_labeled_box(terms_list, checkbox_id, link_terms)
      checkbox = recording_studio_terms_agree_checkbox_tag(terms_list, checkbox_id, link_terms)
      return checkbox unless link_terms && terms_list.size == 1

      content_tag(:div, class: "flex items-center") do
        safe_join([checkbox, recording_studio_terms_agree_linked_label(terms_list.first, checkbox_id)])
      end
    end

    def recording_studio_terms_agree_checkbox_tag(terms_list, checkbox_id, link_terms)
      render(
        FlatPack::Checkbox::Component.new(
          **recording_studio_terms_agree_checkbox,
          id: checkbox_id,
          label: link_terms && terms_list.size == 1 ? nil : recording_studio_terms_agree_label(terms_list)
        )
      )
    end

    def recording_studio_terms_agree_label(_terms_list)
      "I agree to these terms"
    end

    def recording_studio_terms_agree_checkbox
      {
        name: "agreed",
        value: "1",
        checked: true,
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
  end
end
