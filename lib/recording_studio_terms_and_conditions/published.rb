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
          next unless installed?

          emit_from(event.payload)
        rescue StandardError => e
          report_failure(e)
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

      def installed?
        defined?(RecordingStudioPublishable) &&
          RecordingStudioPublishable.configuration.hooks.registered?(LATCH)
      end

      private

      def emit_from(publishable_payload)
        recording_id, terms_id = terms_ids_from(publishable_payload)
        return if recording_id.blank? || terms_id.blank?
        return if skip_persisted_emit?(recording_id, terms_id)

        ActiveSupport::Notifications.instrument(EVENT, recording_id: recording_id, terms_id: terms_id)
      end

      def terms_ids_from(publishable_payload)
        payload = publishable_payload.to_h.symbolize_keys
        return [nil, nil] unless payload[:recordable_type] == TERMS_TYPE

        [payload[:recording_id], payload[:recordable_id]]
      end

      def skip_persisted_emit?(recording_id, terms_id)
        recording = find_terms_recording(recording_id)
        return false unless recording

        SoleLive.call(recording)
        !claim_emit?(recording, terms_id)
      end

      def find_terms_recording(recording_id)
        return unless defined?(RecordingStudio::Recording)

        RecordingStudio::Recording.find_by(id: recording_id)
      rescue StandardError
        nil
      end

      def claim_emit?(recording, terms_id)
        key = idempotency_key(recording, terms_id)
        return false if recording.event_by_idempotency_key(key)

        recording.log_event!(action: "published", idempotency_key: key)
        true
      rescue RecordingStudio::IdempotencyError
        false
      end

      def idempotency_key(recording, terms_id)
        "#{EVENT}:#{recording.id}:#{terms_id}"
      end

      def report_failure(error)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error(
            "[RecordingStudioTermsAndConditions] published subscriber failed: " \
            "#{error.class}: #{error.message}"
          )
        end
        return unless defined?(Rails) && Rails.respond_to?(:error) && Rails.error

        Rails.error.report(error, handled: true)
      end
    end
  end
end
