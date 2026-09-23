# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # One document lineage per kind per workspace. Admin create is blocked when any recording
  # of that kind already exists; later versions come from fork/edit only.
  class KindPresence
    class << self
      def exists?(root, kind:)
        recordings_for(root, kind: kind).any?
      end

      def recordings_for(root, kind:)
        root_recording = resolve_root_recording(root)
        return [] if root_recording.blank?

        wanted = Terms.normalize_kind(kind)
        root_recording.recordings_query(include_children: true, type: Terms.name).select do |recording|
          recording.trashed_at.blank? && recording.recordable&.kind.to_s == wanted
        end
      end

      def available_kinds(root)
        Terms::KINDS.reject { |kind| exists?(root, kind: kind) }
      end

      private

      def resolve_root_recording(root)
        return if root.blank?
        return recording_root(root) if root.is_a?(RecordingStudio::Recording)
        return unless root.respond_to?(:id) && root.id.present?

        RecordingStudio.root_recording_for(root)
      rescue StandardError
        nil
      end

      def recording_root(recording)
        recording.parent_recording_id.blank? ? recording : recording.root_recording
      end
    end
  end
end
