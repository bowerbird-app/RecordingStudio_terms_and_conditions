# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Host helper: drop the required Agree checkbox on a page or inside a host form.
  # Persistence stays on Acceptance via accept! / AcceptancesController.
  module AgreeHelper
    def recording_studio_terms_agree(inside_form: false, actor: nil, root: nil)
      root ||= recording_studio_terms_agree_root
      terms = RecordingStudioTermsAndConditions.current_published_for(root)
      return if terms.blank?

      actor ||= recording_studio_terms_agree_actor
      return if actor.present? && RecordingStudioTermsAndConditions.accepted?(actor, root)

      recording_studio_terms_agree_fields(terms)
    end

    private

    def recording_studio_terms_agree_fields(terms)
      checkbox = render(FlatPack::Checkbox::Component.new(**recording_studio_terms_agree_checkbox))
      safe_join([checkbox, recording_studio_terms_agree_full_terms_link(terms)].compact)
    end

    def recording_studio_terms_agree_checkbox
      {
        name: "agreed",
        value: "1",
        checked: false,
        required: true,
        label: "I agree to these terms"
      }
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
