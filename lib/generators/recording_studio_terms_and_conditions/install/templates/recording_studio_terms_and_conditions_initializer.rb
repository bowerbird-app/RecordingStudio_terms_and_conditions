# frozen_string_literal: true

RecordingStudioTermsAndConditions.configure do |config|
  # Path used by admin_terms_path and the Agree screen mount.
  # config.mount_path = "/recording_studio_terms_and_conditions"

  # Optional display name. When blank, the gem uses RecordingStudioSiteSettings.name_for
  # if that method exists. Site Settings is not required.
  # config.app_name = "Your app"

  # Optional. Host helper only. The gem Agree screen ignores this flag.
  # When true on a host wrap, Agree stays disabled until the live copy is scrolled
  # to the end. Pass require_scroll_to_end: true to recording_studio_terms_scroll_to_end
  # / recording_studio_terms_agree_button. Missing IntersectionObserver leaves Agree
  # enabled so keyboard users are not stuck.
  # config.require_scroll_to_end = false

  # Optional. When true, the gem Agree screen stores IP and user agent in provenance.
  # Default stays off. Direct accept! callers pass their own provenance hash.
  # config.capture_request_provenance = false

  # Controller paths the clickwrap skips, on top of Agree, Admin, and health.
  # Append your auth controllers so sign-in can finish.
  # config.gate_exempt_controllers += %w[host/auth]

  # Who-agreed search. Receives the acceptance relation and the typed term.
  # Return the relation. Leave unset and the name filter does not narrow the list.
  # config.actor_name_search = ->(relation, _term) { relation }

  # Users 0.36 has no after-sign-in setting, and the return-path method is private.
  # Prepend a public after_sign_in_path_for / after_sign_up_path_for on the auth
  # controller that returns Gate.after_auth_path(self, user) || super.
end
