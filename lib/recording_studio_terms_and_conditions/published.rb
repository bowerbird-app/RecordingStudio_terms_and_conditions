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

        hooks = RecordingStudio.configuration.hooks
        return if hooks.registered?(LATCH)

        hooks.on(LATCH) { true }
        subscribe_publishable!
      end

      def subscribe_publishable!
        return if @publishable_subscribed

        @publishable_subscribed = true
        RecordingStudioPublishable.subscribe(:published) do |event|
          next unless installed?

          emit_from(event.payload)
        end
      end
      private :subscribe_publishable!

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
        defined?(RecordingStudio) && RecordingStudio.configuration.hooks.registered?(LATCH)
      end

      def claim_emit?(recording, terms_id)
        PublishedEmitter.claim_emit?(recording, terms_id)
      end
      private :claim_emit?

      private

      def emit_from(publishable_payload)
        PublishedEmitter.emit_from(publishable_payload)
      end
    end
  end

  class PublishedEmitter
    class << self
      def emit_from(publishable_payload)
        recording_id, terms_id = terms_ids_from(publishable_payload)
        return if recording_id.blank? || terms_id.blank?

        recording = lookup_terms_recording(recording_id)
        return if recording == :failed

        if recording
          emit_for_recording(recording, terms_id, actor: actor_from(publishable_payload))
        else
          instrument_terms_event(recording_id, terms_id)
        end
      end

      def claim_emit?(recording, terms_id)
        recording.with_lock { take_claim?(recording, idempotency_key(recording, terms_id)) }
      rescue RecordingStudio::IdempotencyError
        false
      end

      private

      def terms_ids_from(publishable_payload)
        payload = publishable_payload.to_h.symbolize_keys
        return [nil, nil] unless payload[:recordable_type] == Published::TERMS_TYPE

        [payload[:recording_id], payload[:recordable_id]]
      end

      def emit_for_recording(recording, terms_id, actor: nil)
        SoleLive.call(recording, actor: actor)
        recording.with_lock do
          next if claimed?(recording, terms_id)
          next unless instrument_terms_event(recording.id, terms_id)

          take_claim?(recording, idempotency_key(recording, terms_id), actor: actor)
        end
      end

      def actor_from(payload)
        data = payload.to_h.symbolize_keys
        type = data[:actor_type].to_s
        id = data[:actor_id]
        return if type.blank? || id.blank?

        klass = type.safe_constantize
        return unless klass.respond_to?(:find_by)

        klass.find_by(id: id)
      end

      def lookup_terms_recording(recording_id)
        return unless lookup_ready?

        RecordingStudio::Recording.find_by(id: recording_id)
      rescue StandardError => e
        report_failure(e)
        :failed
      end

      def lookup_ready?
        defined?(RecordingStudio::Recording) &&
          RecordingStudio::Recording.respond_to?(:connected?) &&
          RecordingStudio::Recording.connected?
      end

      def instrument_terms_event(recording_id, terms_id)
        ActiveSupport::Notifications.instrument(
          Published::EVENT,
          recording_id: recording_id,
          terms_id: terms_id
        )
        true
      rescue StandardError => e
        report_failure(e)
        false
      end

      def take_claim?(recording, key, actor: nil)
        before_ids = recording.events.where(idempotency_key: key).pluck(:id)
        event = recording.log_event!(
          action: "published",
          idempotency_key: key,
          actor: SoleLive.write_actor_for(recording, actor: actor)
        )
        created_claim?(before_ids, event)
      end

      def created_claim?(before_ids, event)
        event.present? && before_ids.exclude?(event.id)
      end

      def claimed?(recording, terms_id)
        recording.event_by_idempotency_key(idempotency_key(recording, terms_id)).present?
      end

      def idempotency_key(recording, terms_id)
        "#{Published::EVENT}:#{recording.id}:#{terms_id}"
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
