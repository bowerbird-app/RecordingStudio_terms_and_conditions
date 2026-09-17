# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class TermsAcceptance # rubocop:disable Metrics/ClassLength
    class << self
      def current_published_for(root)
        root_recording = resolve_root_recording(root)
        return if root_recording.blank?

        published_terms_recording_for(root_recording)&.recordable
      end

      def accepted?(actor, root)
        return false if actor.blank?

        terms = current_published_for(root)
        return false if terms.blank?

        recording = recording_for_terms(terms)
        return false if recording.blank?

        acceptance_exists?(actor: actor, terms_recording_id: recording.id, terms_id: terms.id)
      end

      def requires_acceptance?(actor, root)
        pending_published_list(actor, root).any?
      end

      def reaccepting?(actor, root)
        terms = pending_published_for(actor, root)
        recording = recording_for_terms(terms)
        return false if actor.blank? || recording.blank?

        Acceptance.where(
          actor_type: actor.class.base_class.name,
          actor_id: actor.id,
          terms_recording_id: sibling_terms_recording_ids(recording)
        ).where.not(terms_id: terms.id).exists?
      end

      def pending_published_for(actor, root)
        pending_published_list(actor, root).first
      end

      def pending_published_list(actor, root)
        terms = current_published_for(root)
        return [] if terms.blank? || accepted?(actor, root)

        [terms]
      end

      def accept!(actor, version, provenance = {})
        raise ArgumentError, "actor is required" if actor.blank?

        recording, terms = resolve_version(version)
        raise ArgumentError, "version must be Terms or a Terms recording" if recording.blank? || terms.blank?
        raise NotLive, "Only live terms can be accepted." unless live_version?(recording)

        create_receipt!(actor: actor, recording: recording, terms: terms, provenance: provenance)
      end

      private

      def create_receipt!(actor:, recording:, terms:, provenance:)
        existing = receipt_for(actor: actor, terms_recording_id: recording.id, terms_id: terms.id)
        return existing if existing

        insert_receipt!(actor: actor, recording: recording, terms: terms, provenance: provenance)
      rescue ActiveRecord::RecordNotUnique
        receipt_for(actor: actor, terms_recording_id: recording.id, terms_id: terms.id) || raise
      end

      def insert_receipt!(actor:, recording:, terms:, provenance:)
        Acceptance.create!(
          actor: actor,
          terms_recording_id: recording.id,
          terms_id: terms.id,
          accepted_at: Time.current,
          body_digest: BodyDigest.call(terms.body),
          provenance: normalize_provenance(provenance)
        )
      end

      def receipt_for(actor:, terms_recording_id:, terms_id:)
        Acceptance.find_by(
          actor_type: actor.class.base_class.name,
          actor_id: actor.id,
          terms_recording_id: terms_recording_id,
          terms_id: terms_id
        )
      end

      def resolve_root_recording(root)
        return if root.blank?
        return recording_root(root) if root.is_a?(RecordingStudio::Recording)
        return unless persisted_root_recordable?(root)

        RecordingStudio.root_recording_for(root)
      end

      def recording_root(recording)
        recording.parent_recording_id.blank? ? recording : recording.root_recording
      end

      def persisted_root_recordable?(root)
        root.respond_to?(:id) && root.id.present? && RecordingStudio.root_allowed?(root.class.name)
      end

      def sibling_terms_recording_ids(recording)
        SoleLive.terms_recordings_for(recording).map(&:id)
      end

      def published_terms_recording_for(root_recording)
        candidates = root_recording.recordings_query(include_children: true, type: Terms.name)
        candidates.select(&:currently_published?).max_by { |recording| publish_sort_key(recording) }
      end

      def publish_sort_key(recording)
        [recording.current_publishable&.publish_at || recording.created_at, recording.created_at]
      end

      def live_version?(recording)
        recording.respond_to?(:currently_published?) && recording.currently_published?
      end

      def resolve_version(version)
        if version.is_a?(RecordingStudio::Recording)
          terms = version.recordable
          return unless terms.is_a?(Terms)

          [version, terms]
        elsif version.is_a?(Terms)
          recording = recording_for_terms(version)
          [recording, version] if recording
        end
      end

      def recording_for_terms(terms)
        return if terms.blank?

        RecordingStudio::Recording.find_by(recordable_type: Terms.name, recordable_id: terms.id) ||
          RecordingStudio::Event.find_by(recordable_type: Terms.name, recordable_id: terms.id)&.recording
      end

      def acceptance_exists?(actor:, terms_recording_id:, terms_id:)
        receipt_for(actor: actor, terms_recording_id: terms_recording_id, terms_id: terms_id).present?
      end

      def normalize_provenance(provenance)
        return {} if provenance.nil?
        raise ArgumentError, "provenance must be a hash" unless provenance.respond_to?(:to_h)

        provenance.to_h.stringify_keys.except("body_digest", "body_digest_algorithm")
      end
    end
  end # rubocop:enable Metrics/ClassLength
end
