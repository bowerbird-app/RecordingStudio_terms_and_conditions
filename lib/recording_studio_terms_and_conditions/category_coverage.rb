# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Admin index coverage: live/draft/agrees counted per category.
  class CategoryCoverage
    class << self
      def rows(recordings)
        by_category = Array(recordings).group_by { |recording| recording.recordable&.category }
        Terms::CATEGORIES.map { |category| row_for(category, by_category[category] || []) }
      end

      private

      def row_for(category, matching)
        {
          category: Terms::CATEGORY_LABELS.fetch(category, category),
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
