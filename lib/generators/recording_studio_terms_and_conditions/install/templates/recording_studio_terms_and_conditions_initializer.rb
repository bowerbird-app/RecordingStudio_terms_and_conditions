# frozen_string_literal: true

RecordingStudioTermsAndConditions.configure do |config|
  # Path used by admin_terms_path and the Agree screen mount.
  # config.mount_path = "/recording_studio_terms_and_conditions"

  # Optional. When true, Agree stays disabled until the live copy is scrolled to the end.
  # The required checkbox still applies. Hosts can also pass require_scroll_to_end: true
  # to recording_studio_terms_scroll_to_end / recording_studio_terms_agree_button.
  # config.require_scroll_to_end = false
end
