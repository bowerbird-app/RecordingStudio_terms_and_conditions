# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Soft hook: continuing create-password accepts pending live Terms.
  module SignupAcceptance
    def create_password
      @_recording_studio_terms_signup_accept = true
      super
    end

    def finish_sign_up!(user)
      accept_signup_terms!(user) if @_recording_studio_terms_signup_accept
      super
    end

    private

    def accept_signup_terms!(actor)
      return if actor.blank?

      root = Gate.root_for_signup(self)
      RecordingStudioTermsAndConditions.pending_published_list(actor, root).each do |terms|
        RecordingStudioTermsAndConditions.accept!(actor, terms, { "source" => "continue_notice" })
      end
    rescue RecordingStudioTermsAndConditions::NotLive
      nil
    end
  end
end
