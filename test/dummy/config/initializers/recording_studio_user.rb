# frozen_string_literal: true

# Dummy signs in with Recording Studio Users Auth. The gem prepends the
# post-auth redirect so signup and sign in land on Agree when required.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.otp_enabled = false
  # Dummy User is not Devise :confirmable. Skip Users' existing-policy confirm write.
  config.password_registration_confirmation = :skip
  config.additional_profile_attributes |= [:locale] if config.respond_to?(:additional_profile_attributes)
  # Users Auth 0.27 resolves recording_studio_layout from this setting. Nil
  # falls through to core DEFAULT_LAYOUT. Dummy sign-in uses layouts/application
  # so the page is not wrapped in data-recording-studio-default-layout.
  config.layout = "application"
end
