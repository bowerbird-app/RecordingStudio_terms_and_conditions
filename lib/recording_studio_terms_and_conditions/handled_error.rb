# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module HandledError
    module_function

    def log(error, context)
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn(
          "[RecordingStudioTermsAndConditions] #{context}: #{error.class}: #{error.message}"
        )
      end
      return unless defined?(Rails) && Rails.respond_to?(:error) && Rails.error

      Rails.error.report(error, handled: true)
    end
  end
end
