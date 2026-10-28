# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module EngineRuntime
    module_function

    def install!
      AcceptanceGateInstaller.call
      SoleLive.install!
      Published.install!
      Engine.prepend_users_signup_view_path
    end
  end
end
