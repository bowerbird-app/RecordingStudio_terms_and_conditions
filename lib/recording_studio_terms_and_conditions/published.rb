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

        recording = lookup_terms_recording(recording_id)
        return if recording == :failed

        if recording
          emit_for_recording(recording, terms_id)
        else
          instrument_terms_event(recording_id, terms_id)
        end
      end

      def terms_ids_from(publishable_payload)
        payload = publishable_payload.to_h.symbolize_keys
        return [nil, nil] unless payload[:recordable_type] == TERMS_TYPE

        [payload[:recording_id], payload[:recordable_id]]
      end

      def emit_for_recording(recording, terms_id)
        SoleLive.call(recording)
        recording.with_lock do
          next if claimed?(recording, terms_id)
          next unless instrument_terms_event(recording.id, terms_id)

          take_claim?(recording, idempotency_key(recording, terms_id))
        end
      end

      def lookup_terms_recording(recording_id)
        return unless lookup_ready?

        RecordingStudio::Recording.find_by(id: recording_id)
      rescue ArgumentError => e
        HandledError.log(e, "published lookup failed", severity: :error)
        :failed
      rescue StandardError => e
        raise unless active_record_error?(e)

        HandledError.log(e, "published lookup failed", severity: :error)
        :failed
      end

      def lookup_ready?
        defined?(RecordingStudio::Recording) &&
          RecordingStudio::Recording.respond_to?(:connected?) &&
          RecordingStudio::Recording.connected?
      end

      def active_record_error?(error)
        defined?(::ActiveRecord::ActiveRecordError) && error.is_a?(::ActiveRecord::ActiveRecordError)
      end

      def instrument_terms_event(recording_id, terms_id)
        ActiveSupport::Notifications.instrument(EVENT, recording_id: recording_id, terms_id: terms_id)
        true
      rescue StandardError => e
        HandledError.log(e, "published subscriber failed", severity: :error)
        false
      end

      def claim_emit?(recording, terms_id)
        recording.with_lock { take_claim?(recording, idempotency_key(recording, terms_id)) }
      rescue RecordingStudio::IdempotencyError
        false
      end

      def take_claim?(recording, key)
        before_ids = recording.events.where(idempotency_key: key).pluck(:id)
        event = recording.log_event!(action: "published", idempotency_key: key)
        created_claim?(before_ids, event)
      end

      def created_claim?(before_ids, event)
        event.present? && before_ids.exclude?(event.id)
      end

      def claimed?(recording, terms_id)
        recording.event_by_idempotency_key(idempotency_key(recording, terms_id)).present?
      end

      def idempotency_key(recording, terms_id)
        "#{EVENT}:#{recording.id}:#{terms_id}"
      end
    end
  end
end
