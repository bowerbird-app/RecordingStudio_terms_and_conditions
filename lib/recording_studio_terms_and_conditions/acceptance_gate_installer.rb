# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Wires the clickwrap gate onto the host and Users Auth controllers.
  class AcceptanceGateInstaller
    def self.call
      new.install
    end

    def install
      include_host_gate
      prepend_users_auth_redirect
      prepend_users_signup_acceptance
    end

    private

    def include_host_gate
      host = "::ApplicationController".safe_constantize
      return unless host
      return if host.include?(ForcesAcceptance)

      host.include ForcesAcceptance
    end

    def prepend_users_auth_redirect
      auth = "RecordingStudioUser::Auth::BaseController".safe_constantize
      return unless auth
      return if auth.ancestors.include?(UsersAuthRedirect)

      auth.prepend UsersAuthRedirect
    end

    def prepend_users_signup_acceptance
      registrations = "RecordingStudioUser::Auth::RegistrationsController".safe_constantize
      return unless registrations
      return if registrations.ancestors.include?(SignupAcceptance)

      registrations.prepend SignupAcceptance
    end
  end
end
