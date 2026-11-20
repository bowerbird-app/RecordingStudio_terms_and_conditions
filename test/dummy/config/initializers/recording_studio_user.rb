# frozen_string_literal: true

# Dummy signs in with Recording Studio Users Auth.
# Terms hooks config.after_auth_path. Signup consent stays on these two lines.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.otp_enabled = false
  # Users confirms password signups with an email code. Seed and test users call skip_confirmation!.
  # Users 0.30 defaults this to 12. Seed and demo passwords stay "Password".
  config.minimum_password_length = 6
  config.signup_notice_partials << "recording_studio_terms_and_conditions/signup_notice"
  config.after_registration(RecordingStudioTermsAndConditions::SignupRegistration)
  # Dummy-only Google callback. The defaults are placeholders, not a real app.
  # A host leaves omniauth_providers empty and puts the real pair in credentials.
  config.omniauth_providers = {
    google_oauth2: {
      client_id: ENV.fetch("GOOGLE_OAUTH_CLIENT_ID", "dev_placeholder"),
      client_secret: ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET", "dev_placeholder")
    }
  }
  config.sign_up_variants = {
    trial: {
      title: "dummy.signup.trial.title",
      subtitle: "dummy.signup.trial.subtitle"
    }
  }
  config.additional_profile_attributes |= [:locale] if config.respond_to?(:additional_profile_attributes)
  # Users Auth 0.27 resolves recording_studio_layout from this setting. Nil
  # falls through to core DEFAULT_LAYOUT. Dummy sign-in uses layouts/application
  # so the page is not wrapped in data-recording-studio-default-layout.
  config.layout = "application"
end
