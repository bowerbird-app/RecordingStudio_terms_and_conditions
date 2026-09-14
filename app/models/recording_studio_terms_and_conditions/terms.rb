# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Terms < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_terms"

    recording_studio_recordable label: "Terms",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    validates :title, :body, presence: true

    if defined?(RecordingStudio::Capabilities::Publishable)
      include RecordingStudio::Capabilities::Publishable.to(
        public_controller: "recording_studio_terms_and_conditions/published_terms",
        public_action: :show,
        public_layout: "recording_studio/default_layout",
        path: "/terms/:uuid/:slug",
        schedule: true,
        seo: false
      )
    end
  end
end
