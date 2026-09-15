# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Admin index coverage: live/draft/agrees counted per kind.
  class KindCoverage
    class << self
      def rows(recordings)
        by_kind = Array(recordings).group_by { |recording| recording.recordable&.kind }
        Terms::KINDS.map { |kind| row_for(kind, by_kind[kind] || []) }
      end

      private

      def row_for(kind, matching)
        {
          kind: Terms::KIND_LABELS.fetch(kind, kind),
          status: status_for(matching),
          agrees: matching.sum { |recording| Acceptance.where(terms_recording_id: recording.id).count }
        }
      end

      def status_for(matching)
        return "Live" if matching.any? { |recording| live?(recording) }
        return "Draft" if matching.any?

        "—"
      end

      def live?(recording)
        recording.respond_to?(:currently_published?) && recording.currently_published?
      end
    end
  end
end
