# frozen_string_literal: true

RecordingStudioTermsAndConditions.configure do |config|
  # config.mount_path = "/recording_studio_terms_and_conditions"

  # Dummy opts in so the Agree screen proves the optional scroll gate.
  config.require_scroll_to_end = true
end
