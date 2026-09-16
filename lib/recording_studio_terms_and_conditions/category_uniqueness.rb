# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Sets workspace + recording context on Terms before RecordingStudio.record! saves.
  # Uniqueness lives on the model (hook errors are swallowed unless raise_on_error).
  class CategoryUniqueness
    class << self
      def install!
        return if @installed

        RecordingStudio.configuration.hooks.before_record(self)
        @installed = true
      end

      def call(*args, **kwargs)
        payload = args.first.is_a?(Hash) ? args.first : kwargs
        recordable = payload[:recordable] || payload["recordable"]
        return unless recordable.is_a?(Terms)

        recordable.category_scope_recording = payload[:recording] || payload["recording"]
        recordable.category_scope_root_recording = payload[:root_recording] || payload["root_recording"]
      end
    end
  end
end
