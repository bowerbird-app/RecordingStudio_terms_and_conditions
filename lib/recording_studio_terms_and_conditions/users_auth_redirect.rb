# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Users Auth after-sign-in / after-sign-up lands on Agree until every pending category is ticked.
  module UsersAuthRedirect
    def after_sign_in_path_for(resource)
      Gate.after_auth_path(self, resource) || super
    end

    def after_sign_up_path_for(resource)
      Gate.after_auth_path(self, resource) || super
    end
  end
end
