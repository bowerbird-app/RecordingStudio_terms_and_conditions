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
    end

    private

    def include_host_gate
      return unless defined?(::ApplicationController)
      return if ::ApplicationController.include?(ForcesAcceptance)

      ::ApplicationController.include ForcesAcceptance
    end

    def prepend_users_auth_redirect
      return unless defined?(RecordingStudioUser::Auth::BaseController)

      auth = RecordingStudioUser::Auth::BaseController
      return if auth.ancestors.include?(UsersAuthRedirect)

      auth.prepend UsersAuthRedirect
    end
  end
end
