# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # After-commit signal that a Terms parent became currently published.
  module Published
    EVENT = "published.recording_studio_terms_and_conditions"
    TERMS_TYPE = "RecordingStudioTermsAndConditions::Terms"
    LATCH = :recording_studio_terms_published

    class << self
      def install!
        return unless defined?(RecordingStudioPublishable)
        return if RecordingStudioPublishable.configuration.hooks.registered?(LATCH)

        RecordingStudioPublishable.configuration.hooks.on(LATCH) { true }
        RecordingStudioPublishable.subscribe(:published) do |event|
          emit_from(event.payload)
        end
      end

      def subscribe(&block)
        ActiveSupport::Notifications.subscribe(EVENT) do |*args|
          if block.arity == 1
            block.call(ActiveSupport::Notifications::Event.new(*args))
          else
            block.call(*args)
          end
        end
      end

      private

      def emit_from(publishable_payload)
        payload = publishable_payload.to_h.symbolize_keys
        return unless payload[:recordable_type] == TERMS_TYPE

        recording_id = payload[:recording_id]
        terms_id = payload[:recordable_id]
        return if recording_id.blank? || terms_id.blank?

        ActiveSupport::Notifications.instrument(EVENT, recording_id: recording_id, terms_id: terms_id)
      end
    end
  end
end
