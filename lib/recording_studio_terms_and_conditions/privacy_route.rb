# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Host route for public Privacy Policy pages. Publishable keeps /terms/:uuid/:slug on Terms;
  # privacy rows share the same published controller under /privacy/:uuid/:slug.
  module PrivacyRoute
    module_function

    def draw!(mapper)
      mapper.get(
        "/privacy/:uuid/:slug",
        to: "recording_studio_publishable/published#show",
        defaults: { parent_recordable_type: Terms.name },
        as: :recording_studio_terms_and_conditions_privacy
      )
    end
  end
end
