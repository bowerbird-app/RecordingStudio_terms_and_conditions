# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Soft hook: accept pending live Terms after Users create_password when agreed.
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
      return unless agreed_at_signup?
      return if actor.blank?

      root = Gate.root_for_signup(self)
      RecordingStudioTermsAndConditions.pending_published_list(actor, root).each do |terms|
        RecordingStudioTermsAndConditions.accept!(actor, terms, { "source" => "signup" })
      end
    rescue RecordingStudioTermsAndConditions::NotLive
      nil
    end

    def agreed_at_signup?
      value = params[:agreed]
      value == true || %w[1 true yes on].include?(value.to_s.strip.downcase)
    end
  end
end
