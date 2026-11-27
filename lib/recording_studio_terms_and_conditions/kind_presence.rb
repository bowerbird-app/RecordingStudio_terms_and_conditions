# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # One document lineage per kind on the shared library. Admin create is blocked when any
  # recording of that kind already exists; later versions come from fork/edit only.
  class KindPresence
    class << self
      def exists?(kind:)
        recordings_for(kind: kind).any?
      end

      def recordings_for(kind:)
        root_recording = RecordingStudioTermsAndConditions.library_root
        return [] if root_recording.blank?

        wanted = Terms.normalize_kind(kind)
        root_recording.recordings_query(include_children: true, type: Terms.name).select do |recording|
          recording.trashed_at.blank? && recording.recordable&.kind.to_s == wanted
        end
      end

      def available_kinds
        Terms::KINDS.reject { |kind| exists?(kind: kind) }
      end

      def blocked_message(kind)
        label = Terms.kind_label_for(kind)
        "#{label} already exists. Open that version and edit to make a new draft."
      end
    end
  end
end
