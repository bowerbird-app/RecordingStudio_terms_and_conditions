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

      content_tag(:div, class: "my-3") do
        recording_studio_terms_agree_labeled_box(terms_list, checkbox_id, link_terms)
      end
    end

    def recording_studio_terms_agree_labeled_box(terms_list, checkbox_id, link_terms)
      if link_terms
        content_tag(:div, class: "flex items-center") do
          safe_join([
                      recording_studio_terms_agree_checkbox_tag(terms_list, checkbox_id, linked: true),
                      recording_studio_terms_agree_linked_label(terms_list, checkbox_id)
                    ])
        end
      else
        recording_studio_terms_agree_checkbox_tag(terms_list, checkbox_id, linked: false)
      end
    end

    def recording_studio_terms_agree_checkbox_tag(terms_list, checkbox_id, linked:)
      render(
        FlatPack::Checkbox::Component.new(
          **recording_studio_terms_agree_checkbox,
          id: checkbox_id,
          label: linked ? nil : recording_studio_terms_agree_label(terms_list)
        )
      )
    end

    def recording_studio_terms_agree_label(terms_list)
      if terms_list_includes_privacy?(terms_list)
        "I agree to these terms and privacy policy"
      else
        "I agree to these terms"
      end
    end

    def recording_studio_terms_agree_checkbox
      {
        name: "agreed",
        value: "1",
        checked: true,
        required: true
      }
    end

    def recording_studio_terms_agree_linked_label(terms_list, checkbox_id)
      label_tag(
        checkbox_id,
        safe_join(["I agree to these ".html_safe, recording_studio_terms_agree_linked_words(terms_list)]),
        class: "ml-[var(--checkbox-label-gap)] text-sm font-medium " \
               "text-[var(--surface-content-color)] cursor-pointer"
      )
    end

    def recording_studio_terms_agree_linked_words(terms_list)
      terms_doc = terms_list.find { |terms| terms.try(:terms_and_condition?) } || terms_list.first
      privacy_doc = terms_list.find { |terms| terms.try(:privacy_policy?) }

      words = [recording_studio_terms_word_link(terms_doc)]
      if privacy_doc
        words << " and ".html_safe
        words << recording_studio_privacy_word_link(privacy_doc)
      end
      safe_join(words)
    end

    def recording_studio_terms_word_link(terms)
      url = terms.try(:published_url)
      return "terms" if url.blank?

      render(FlatPack::Link::Component.new(href: url).with_content("terms"))
    end

    def recording_studio_privacy_word_link(terms)
      url = terms.try(:published_url)
      return "privacy policy" if url.blank?

      render(
        FlatPack::Link::Component.new(href: url, target: "_blank").with_content("privacy policy")
      )
    end

    def terms_list_includes_privacy?(terms_list)
      Array(terms_list).any? { |terms| terms.try(:privacy_policy?) }
    end
  end
end
