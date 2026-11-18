# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Records signup consent from Users after_registration and the signup notice.
  module SignupRegistration
    PARTIAL = "recording_studio_terms_and_conditions/signup_notice"

    class << self
      def install!
        install_notice!
        install_hook!
      end

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

      def install_notice!
        config = users_config
        return unless notice_list?(config)

        partials = Array(config.signup_notice_partials)
        return if partials.include?(PARTIAL)

        config.signup_notice_partials = partials + [PARTIAL]
      end

      def install_hook!
        config = users_config
        return unless hook_list?(config)
        return if Array(config.after_registration_hooks).include?(self)

        config.after_registration(self)
      end

      def notice_list?(config)
        config.respond_to?(:signup_notice_partials) && config.respond_to?(:signup_notice_partials=)
      end

      def hook_list?(config)
        config.respond_to?(:after_registration_hooks) && config.respond_to?(:after_registration)
      end

      def users_config
        return unless defined?(RecordingStudioUser)

        RecordingStudioUser.config
      end
    end
  end
end
