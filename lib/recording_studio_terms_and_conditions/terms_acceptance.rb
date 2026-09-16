# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Domain helpers for live published Terms and append-only acceptances.
  class TermsAcceptance # rubocop:disable Metrics/ClassLength
    class << self
      def current_published_for(root, category: Terms::DEFAULT_CATEGORY)
        wanted = Terms.normalize_category(category)
        return if Terms::CATEGORIES.exclude?(wanted)

        current_published_by_category(root)[wanted]
      end

      def current_published_by_category(root)
        root_recording = resolve_root_recording(root)
        return {} if root_recording.blank?

        published_recordables_by_category(root_recording)
      end

      def accepted?(actor, root, category: Terms::DEFAULT_CATEGORY)
        return false if actor.blank?

        terms = current_published_for(root, category: category)
        return false if terms.blank?

        recording = recording_for_terms(terms)
        return false if recording.blank?

        acceptance_exists?(actor: actor, terms_recording_id: recording.id, terms_id: terms.id)
      end

      def requires_acceptance?(actor, root, category: nil, required_categories: nil)
        pending_categories_for(actor, root, category: category, required_categories: required_categories).any?
      end

      def reaccepting?(actor, root, category: nil, required_categories: nil)
        pending = pending_categories_for(
          actor, root, category: category, required_categories: required_categories
        )
        pending.any? { |pending_category| reaccepting_category?(actor, root, pending_category) }
      end

      def pending_published_for(actor, root, required_categories: nil)
        pending_published_list(actor, root, required_categories: required_categories).first
      end

      def pending_published_list(actor, root, required_categories: nil)
        pending_categories_for(actor, root, required_categories: required_categories).filter_map do |category|
          current_published_for(root, category: category)
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

      def pending_categories_for(actor, root, category: nil, required_categories: nil)
        gated = gated_categories(root, category: category, required_categories: required_categories)
        gated.select do |pending_category|
          current_published_for(root, category: pending_category).present? &&
            !accepted?(actor, root, category: pending_category)
        end
      end

      def gated_categories(root, category:, required_categories:)
        return normalized_category_list(category) if category.present?

        listed = if required_categories.nil?
                   RecordingStudioTermsAndConditions.configuration.required_categories
                 else
                   required_categories
                 end
        listed.nil? ? current_published_by_category(root).keys : normalized_category_list(listed)
      end

      def normalized_category_list(value)
        Array(value).map { |item| Terms.normalize_category(item) }.uniq.select do |item|
          Terms::CATEGORIES.include?(item)
        end
      end

      def reaccepting_category?(actor, root, category)
        terms = current_published_for(root, category: category)
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

      def published_recordables_by_category(root_recording)
        chosen = latest_live_recordings_by_category(root_recording)
        Terms::CATEGORIES.each_with_object({}) do |category, map|
          map[category] = chosen[category].recordable if chosen[category]
        end
      end

      def latest_live_recordings_by_category(root_recording)
        recordings = root_recording.recordings_query(include_children: true, type: Terms.name)
        recordings.each_with_object({}) do |recording, chosen|
          category = live_terms_category(recording)
          next if category.blank? || keep_existing_recording?(chosen[category], recording)

          chosen[category] = recording
        end
      end

      def live_terms_category(recording)
        return unless recording.currently_published?

        category = recording.recordable&.category.to_s
        category if Terms::CATEGORIES.include?(category)
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
