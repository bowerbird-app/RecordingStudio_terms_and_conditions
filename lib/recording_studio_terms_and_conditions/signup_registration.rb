# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Accepts each pending live document for a new account.
  #
  # Hosts pass this callable to their own registration hook:
  # call(user:, method:). Provenance is source "signup" and the method string.
  # NotLive skips that document. Any other error returns nil so account
  # creation still succeeds. Receipts still store body_digest.
  module SignupRegistration
    class << self
      def call(user:, method:)
        return if user.blank?

        provenance = { "source" => "signup", "method" => method.to_s }
        RecordingStudioTermsAndConditions.pending_published_list(user).each do |terms|
          accept_pending(user, terms, provenance)
        end
        nil
      rescue StandardError
        nil
      end

      private

      def accept_pending(user, terms, provenance)
        RecordingStudioTermsAndConditions.accept!(user, terms, provenance)
      rescue NotLive
        nil
      end
    end
  end
end
