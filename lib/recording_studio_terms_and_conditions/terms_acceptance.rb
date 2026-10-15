# frozen_string_literal: true

module RecordingStudioTermsAndConditions
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

      def requires_acceptance?(actor, root)
        pending_published_list(actor, root).any?
      end

      def reaccepting?(actor, root)
        pending_published_list(actor, root).any? do |terms|
          reaccepting_kind?(actor, terms)
        end
      end

      def reaccepting_actors_for(recording_id:, terms_id:)
        recording, terms = live_current_version(recording_id, terms_id)
        return [] if recording.blank? || terms.blank?

        older_actors_for(recording, terms) - current_actors_for(recording, terms)
      end

      def accepted_any?(actor)
        return false if actor.blank?

        Acceptance.where(
          actor_type: actor.class.base_class.name,
          actor_id: actor.id
        ).exists?
      end

      def pending_published_for(actor, root)
        pending_published_list(actor, root).first
      end

      def pending_published_list(actor, root)
        Terms::KINDS.filter_map do |kind|
          terms = current_published_for(root, kind: kind)
          next if terms.blank?
          next if actor.present? && accepted?(actor, root, kind: kind)

          terms
        end
      end

      def accept!(actor, version, provenance = {})
        raise ArgumentError, "actor is required" if actor.blank?

        recording, terms = resolve_version(version)
        raise ArgumentError, "version must be Terms or a Terms recording" if recording.blank? || terms.blank?
        raise NotLive, Copy.t("errors.not_live") unless live_version?(recording)

        create_receipt!(actor: actor, recording: recording, terms: terms, provenance: provenance)
      end

      private

      def reaccepting_kind?(actor, terms)
        recording = recording_for_terms(terms)
        return false if actor.blank? || recording.blank?

        Acceptance.where(
          actor_type: actor.class.base_class.name,
          actor_id: actor.id,
          terms_recording_id: sibling_terms_recording_ids(recording, kind: terms.kind)
        ).where.not(terms_id: terms.id).exists?
      end

      def live_current_version(recording_id, terms_id)
        recording = terms_recording_for(recording_id, terms_id)
        terms = Terms.find_by(id: terms_id) if recording
        return unless recording && terms && live_current?(recording, terms)

        [recording, terms]
      end

      def terms_recording_for(recording_id, terms_id)
        recording = RecordingStudio::Recording.find_by(id: recording_id)
        return unless recording&.recordable_type == Terms.name && recording.recordable_id == terms_id

        recording
      end

      def live_current?(recording, terms)
        live_recording_ids([recording.id]).include?(recording.id) &&
          latest_live_recording_for(recording, kind: terms.kind)&.id == recording.id
      end

      def older_actors_for(recording, terms)
        actor_pairs(
          Acceptance.where(terms_recording_id: sibling_terms_recording_ids(recording, kind: terms.kind))
                    .where.not(terms_id: terms.id)
        )
      end

      def current_actors_for(recording, terms)
        actor_pairs(Acceptance.where(terms_recording_id: recording.id, terms_id: terms.id))
      end

      def actor_pairs(scope)
        scope.distinct.pluck(:actor_type, :actor_id)
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

      def sibling_terms_recording_ids(recording, kind:)
        wanted = Terms.normalize_kind(kind)
        return [] if Terms::KINDS.exclude?(wanted)

        SoleLive.terms_recordings_for(recording, kind: wanted).pluck(:id)
      end

      def published_recordables_by_kind(root_recording)
        chosen = latest_live_recordings_by_kind(root_recording)
        Terms::KINDS.each_with_object({}) do |kind, map|
          map[kind] = chosen[kind].recordable if chosen[kind]
        end
      end

      def latest_live_recordings_by_kind(root_recording)
        recordings = root_recording.recordings_query(include_children: true, type: Terms.name)
        live_ids = live_recording_ids(recordings)
        return {} if live_ids.empty?

        choose_live_by_kind(recordings.where(id: live_ids))
      end

      def choose_live_by_kind(live_recordings)
        terms_by_id = Terms.where(id: live_recordings.select(:recordable_id)).index_by(&:id)
        live_recordings.each_with_object({}) do |recording, chosen|
          kind = terms_by_id[recording.recordable_id]&.kind.to_s
          next if Terms::KINDS.exclude?(kind) || keep_existing_recording?(chosen[kind], recording)

          chosen[kind] = recording
        end
      end

      def latest_live_recording_for(recording, kind:)
        wanted = Terms.normalize_kind(kind)
        return if Terms::KINDS.exclude?(wanted)

        siblings = SoleLive.terms_recordings_for(recording, kind: wanted)
        live_ids = live_recording_ids(siblings)
        return if live_ids.empty?

        siblings.where(id: live_ids).max_by { |candidate| publish_sort_key(candidate) }
      end

      def live_recording_ids(recordings)
        scope = if recordings.is_a?(ActiveRecord::Relation)
                  recordings
                else
                  RecordingStudio::Recording.where(id: recordings)
                end
        table = RecordingStudio::Recording.table_name
        now = Time.current
        scope.where("EXISTS (#{live_parent_sql(table)})", now, now).pluck(:id)
      end

      def live_parent_sql(recordings)
        publishables = "recording_studio_publishable_publishables"
        "SELECT 1 FROM #{recordings} AS publishable_recordings " \
          "INNER JOIN #{publishables} AS publishables ON publishables.id = publishable_recordings.recordable_id " \
          "WHERE publishable_recordings.parent_recording_id = #{recordings}.id " \
          "AND publishable_recordings.recordable_type = 'RecordingStudioPublishable::Publishable' " \
          "AND publishable_recordings.trashed_at IS NULL AND publishables.status = 'published' " \
          "AND (publishables.publish_at IS NULL OR publishables.publish_at <= ?) " \
          "AND (publishables.unpublish_at IS NULL OR publishables.unpublish_at > ?)"
      end

      def keep_existing_recording?(winner, recording)
        winner.present? && (publish_sort_key(recording) <=> publish_sort_key(winner)) != 1
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
