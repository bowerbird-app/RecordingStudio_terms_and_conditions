# frozen_string_literal: true

# Dummy signs in with Recording Studio Users Auth. The gem prepends the
# post-auth redirect so signup and sign in land on Agree when required.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.otp_enabled = false
end
