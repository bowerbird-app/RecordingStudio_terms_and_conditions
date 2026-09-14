# frozen_string_literal: true

# Dummy still signs in with Devise. The gem prepends Users Auth so signup and
# post-auth on a host that mounts recording_studio_user_auth_for land on Agree.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.otp_enabled = false
end
