# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Domain helpers for live published Terms and append-only acceptances.
  class TermsAcceptance # rubocop:disable Metrics/ClassLength
    class << self
      def current_published_for(root, kind: Terms::DEFAULT_KIND)
        wanted = Terms.normalize_kind(kind)
        return if Terms::KINDS.exclude?(wanted)

        current_published_by_kind(root)[wanted]
      end

      def current_published_by_kind(root)
        root_recording = resolve_root_recording(root)
        return {} if root_recording.blank?

        published_recordables_by_kind(root_recording)
      end

      def accepted?(actor, root, kind: Terms::DEFAULT_KIND)
        return false if actor.blank?

        terms = current_published_for(root, kind: kind)
        return false if terms.blank?

        recording = recording_for_terms(terms)
        return false if recording.blank?

        acceptance_exists?(actor: actor, terms_recording_id: recording.id, terms_id: terms.id)
      end

      def requires_acceptance?(actor, root, kind: nil, required_kinds: nil)
        pending_kinds_for(actor, root, kind: kind, required_kinds: required_kinds).any?
      end

      def reaccepting?(actor, root, kind: nil, required_kinds: nil)
        pending_kinds_for(actor, root, kind: kind, required_kinds: required_kinds).any? do |pending_kind|
          reaccepting_kind?(actor, root, pending_kind)
        end
      end

      def pending_published_for(actor, root, required_kinds: nil)
        pending_published_list(actor, root, required_kinds: required_kinds).first
      end

      def pending_published_list(actor, root, required_kinds: nil)
        pending_kinds_for(actor, root, required_kinds: required_kinds).filter_map do |kind|
          current_published_for(root, kind: kind)
        end
      end

      def accept!(actor, version, provenance = {})
        raise ArgumentError, "actor is required" if actor.blank?

        recording, terms = resolve_version(version)
        raise ArgumentError, "version must be Terms or a Terms recording" if recording.blank? || terms.blank?
        raise NotLive, "Only live terms can be accepted." unless live_version?(recording)

        create_receipt!(actor: actor, recording: recording, terms: terms, provenance: provenance)
      end

      private

      def pending_kinds_for(actor, root, kind: nil, required_kinds: nil)
        gated_kinds(root, kind: kind, required_kinds: required_kinds).select do |pending_kind|
          current_published_for(root, kind: pending_kind).present? &&
            !accepted?(actor, root, kind: pending_kind)
        end
      end

      def gated_kinds(root, kind:, required_kinds:)
        return normalized_kind_list(kind) if kind.present?

        listed = required_kinds.nil? ? RecordingStudioTermsAndConditions.configuration.required_kinds : required_kinds
        listed.nil? ? current_published_by_kind(root).keys : normalized_kind_list(listed)
      end

      def normalized_kind_list(value)
        Array(value).map { |item| Terms.normalize_kind(item) }.uniq.select { |item| Terms::KINDS.include?(item) }
      end

      def reaccepting_kind?(actor, root, kind)
        terms = current_published_for(root, kind: kind)
        recording = recording_for_terms(terms)
        recording.present? && Acceptance.where(
          actor_type: actor.class.base_class.name,
          actor_id: actor.id,
          terms_recording_id: recording.id
        ).where.not(terms_id: terms.id).exists?
      end

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

      def published_recordables_by_kind(root_recording)
        chosen = latest_live_recordings_by_kind(root_recording)
        Terms::KINDS.each_with_object({}) do |kind, map|
          map[kind] = chosen[kind].recordable if chosen[kind]
        end
      end

      def latest_live_recordings_by_kind(root_recording)
        recordings = root_recording.recordings_query(include_children: true, type: Terms.name)
        recordings.each_with_object({}) do |recording, chosen|
          kind = live_terms_kind(recording)
          next if kind.blank? || keep_existing_recording?(chosen[kind], recording)

          chosen[kind] = recording
        end
      end

      def live_terms_kind(recording)
        return unless recording.currently_published?

        kind = recording.recordable&.kind.to_s
        kind if Terms::KINDS.include?(kind)
      end

      def keep_existing_recording?(winner, recording)
        winner.present? && publish_sort_key(recording) <= publish_sort_key(winner)
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
  end
end
