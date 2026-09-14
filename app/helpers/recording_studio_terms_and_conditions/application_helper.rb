# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module ApplicationHelper
    def terms_page_nav(title:, back_url: nil, back_label: "Back")
      recording_studio_page_nav(
        title: title,
        page_nav_back_url: back_url,
        page_nav_back_label: back_label
      )
    end

    def terms_publishable_edit_path(recording)
      return unless recording && respond_to?(:recording_studio_publishable)

      recording_studio_publishable.edit_recording_publishable_path(recording_id: recording.id)
    end

    def terms_public_url(terms)
      terms.try(:published_url)
    end
  end
end
