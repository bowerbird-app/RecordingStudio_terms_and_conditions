# frozen_string_literal: true

RecordingStudioTermsAndConditions.configure do |config|
  # Path used by admin_terms_path and the Agree screen mount.
  # config.mount_path = "/recording_studio_terms_and_conditions"

  # Optional display name. When blank, the gem uses RecordingStudioSiteSettings.name_for
  # if that method exists. Site Settings is not required.
  # config.app_name = "Your app"

  # Optional. When true, Agree stays disabled until the live copy is scrolled to the end.
  # A sentinel inside a closed collapse does not lock Agree. The required checkbox still
  # applies. Hosts can also pass require_scroll_to_end: true to
  # recording_studio_terms_scroll_to_end / recording_studio_terms_agree_button.
  # Missing IntersectionObserver leaves Agree enabled so keyboard users are not stuck.
  # config.require_scroll_to_end = false

  # Optional. When true, the gem Agree screen stores IP and user agent in provenance.
  # Default stays off. Direct accept! callers pass their own provenance hash.
  # config.capture_request_provenance = false
end
