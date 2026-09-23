# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # One live Terms recording per kind per workspace. Publishing drafts the others of that kind.
  class SoleLive
    HOOK_EVENT = :recording_studio_terms_sole_live

    def self.install!
      return unless defined?(RecordingStudioPublishable)
      return if RecordingStudioPublishable.configuration.hooks.registered?(HOOK_EVENT)

      RecordingStudioPublishable.configuration.hooks.on(HOOK_EVENT) { true }
      RecordingStudioPublishable.configuration.hooks.after_service do |service_class, result|
        call_after_publishable_update(service_class, result)
      end
    end

    def self.call_after_publishable_update(service_class, result)
      return unless service_class == RecordingStudioPublishable::Services::Publishables::Update
      return unless result.respond_to?(:success?) && result.success?

      publishable_recording = result.value
      parent = publishable_recording.respond_to?(:parent_recording) ? publishable_recording.parent_recording : nil
      call(parent)
    end

    def self.call(parent_recording)
      return unless terms_recording?(parent_recording)
      return unless parent_recording.currently_published?

      draft_other_live_of_kind(parent_recording)
    end

    def self.draft_other_live_of_kind(parent_recording)
      kind = parent_recording.recordable&.kind
      terms_recordings_for(parent_recording, kind: kind).each do |recording|
        next if recording.id == parent_recording.id
        next unless recording.currently_published?

        RecordingStudioPublishable::Services::Publishables::Update.call(
          parent_recording: recording,
          attributes: { status: "draft" }
        )
      end
    end

    def self.terms_recording?(recording)
      recording.respond_to?(:recordable_type) && recording.recordable_type == Terms.name
    end

    def self.terms_recordings_for(recording, kind: nil)
      root = recording.root_recording || recording
      recordings = root.recordings_query(include_children: true, type: Terms.name)
      return recordings if kind.blank?

      wanted = Terms.normalize_kind(kind)
      recordings.select { |candidate| candidate.recordable&.kind.to_s == wanted }
    end
  end
end
