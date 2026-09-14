# frozen_string_literal: true

# Users is a hard kit dependency. Dummy still uses Devise for sign-in this slice;
# do not mount recording_studio_user_auth_for until a later signup-wiring slice.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.otp_enabled = false
end
