# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Sends signed-in and newly signed-up people to Agree while live Terms are pending,
  # through Users' public `config.after_auth_path` (Users >= 0.37.0). Terms still does
  # not depend on Users: install! does nothing when Users or the setting is absent.
  module UsersAfterAuthPath
    # Wraps whatever callable the host already set. Terms goes first so pending Terms
    # win over a host landing path; a nil from Terms hands over to the host callable.
    class Callable
      attr_reader :previous

      def initialize(previous)
        @previous = previous
      end

      def call(controller:, user:)
        Gate.after_auth_path(controller, user) ||
          previous&.call(controller: controller, user: user)
      end
    end

    module_function

    # install! reports whether the wrap landed. The name stays install! because hosts
    # and the engine call it as a command, and a false result is "Users is absent".
    def install! # rubocop:disable Naming/PredicateMethod
      return false unless RecordingStudioTermsAndConditions.configuration.users_after_auth_path

      users = "::RecordingStudioUser".safe_constantize
      return false unless users&.respond_to?(:config) # rubocop:disable Lint/RedundantSafeNavigation

      config = users.config
      return false unless config.respond_to?(:after_auth_path) && config.respond_to?(:after_auth_path=)

      current = config.after_auth_path
      config.after_auth_path = Callable.new(current) unless current.is_a?(Callable)
      true
    end
  end
end
