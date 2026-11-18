# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Includes the clickwrap gate on the host ApplicationController.
  class AcceptanceGateInstaller
    def self.call
      new.install
    end

    def install
      host = "::ApplicationController".safe_constantize
      return unless host
      return if host.include?(ForcesAcceptance)

      host.include ForcesAcceptance
    end
  end
end
