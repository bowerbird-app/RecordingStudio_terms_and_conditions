# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Terms < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_terms"

    recording_studio_recordable label: "Terms",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    if defined?(RecordingStudio::Capabilities::Publishable)
      include RecordingStudio::Capabilities::Publishable.to(
        public_action: :show,
        schedule: true,
        seo: false
      )
    end
  end
end
