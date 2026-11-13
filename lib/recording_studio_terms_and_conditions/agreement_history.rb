# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Released snapshots for one kind on one workspace, grouped by the receipt's terms_id.
  module AgreementHistory
    Version = Struct.new(:terms_id, :title, :released_at, :agreement_count, :live, :number, keyword_init: true)

    class << self
      def versions_for(anchor)
        recordings = kind_recordings(anchor)
        by_terms_id = recordings.index_by { |recording| recording.recordable_id.to_s }
        version_list(version_ids(recordings), by_terms_id)
      end

      def find(anchor, terms_id)
        versions_for(anchor).find { |version| version.terms_id == terms_id.to_s }
      end

      def count_for(terms_id)
        Acceptance.where(terms_id: terms_id).count
      end

      def acceptances_for(terms_id)
        Acceptance.where(terms_id: terms_id).includes(:actor).order(accepted_at: :desc)
      end

      private

      def version_list(ids, by_terms_id)
        counts = agreement_counts(ids)
        numbered(ids.map { |terms_id| build_version(terms_id, by_terms_id[terms_id], counts[terms_id]) })
      end

      def numbered(versions)
        ordered = versions.sort_by { |version| [version.released_at || Time.zone.at(0), version.terms_id] }
        ordered.each_with_index { |version, index| version.number = index + 1 }
        ordered.reverse
      end

      def kind_recordings(anchor)
        SoleLive.terms_recordings_for(anchor, kind: anchor.recordable.kind).includes(:recordable).to_a
      end

      def version_ids(recordings)
        released = recordings.select { |recording| released?(recording) }
                             .map { |recording| recording.recordable_id.to_s }
        receipts = Acceptance.where(terms_recording_id: recordings.map(&:id)).distinct.pluck(:terms_id).map(&:to_s)
        (released + receipts).uniq
      end

      def released?(recording)
        Outline.live?(recording) || recording.recordable&.release_manifest.present?
      end

      def agreement_counts(ids)
        return {} if ids.empty?

        Acceptance.where(terms_id: ids).group(:terms_id).count.transform_keys(&:to_s)
      end

      def build_version(terms_id, recording, count)
        terms = recording&.recordable || Terms.find_by(id: terms_id)
        Version.new(
          terms_id: terms_id,
          title: terms&.title.to_s,
          released_at: released_at(recording, terms),
          agreement_count: count.to_i,
          live: recording.present? && Outline.live?(recording)
        )
      end

      def released_at(recording, terms)
        published = recording&.try(:current_publishable)&.try(:publish_at)
        return published if published.present? && Outline.live?(recording)

        terms&.created_at || recording&.created_at
      end
    end
  end
end
