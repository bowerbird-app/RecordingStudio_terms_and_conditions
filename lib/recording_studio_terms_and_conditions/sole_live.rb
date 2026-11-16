# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # One live Terms recording per kind on the shared library. Publishing drafts the others of that kind.
  class SoleLive
    HOOK_EVENT = :recording_studio_terms_sole_live

    def self.install!
      return unless defined?(RecordingStudioPublishable)

      hooks = RecordingStudio.configuration.hooks
      return if hooks.registered?(HOOK_EVENT)

      hooks.on(HOOK_EVENT) { true }
      hooks.after_service { |service_class, result| call_after_publishable_update(service_class, result) }
    end

    def self.call_after_publishable_update(service_class, result)
      return unless service_class == RecordingStudioPublishable::Services::Publishables::Update
      return unless result.respond_to?(:success?) && result.success?

      publishable_recording = result.value
      parent = publishable_recording.respond_to?(:parent_recording) ? publishable_recording.parent_recording : nil
      call(parent)
    end

    def self.call(parent_recording, actor: nil)
      return unless terms_recording?(parent_recording)
      return unless parent_recording.currently_published?

      draft_other_live_of_kind(parent_recording, actor: actor)
    end

    def self.draft_other_live_of_kind(parent_recording, actor: nil)
      kind = parent_recording.recordable&.kind
      terms_recordings_for(parent_recording, kind: kind).each do |recording|
        next if recording.id == parent_recording.id
        next unless recording.currently_published?

        RecordingStudioPublishable::Services::Publishables::Update.call(
          parent_recording: recording,
          attributes: { status: "draft" },
          actor: write_actor_for(parent_recording, actor: actor)
        )
      end
    end

    def self.write_actor_for(_recording = nil, actor: nil)
      return actor if actor.present?

      actor = Current.actor if defined?(Current) && Current.respond_to?(:actor)
      return actor if actor.present?

      raise RecordingStudio::ActorRequired,
            "actor is required for RecordingStudio writes when config.require_actor is true"
    end

    def self.terms_recording?(recording)
      recording.respond_to?(:recordable_type) && recording.recordable_type == Terms.name
    end

    def self.terms_recordings_for(recording, kind: nil)
      root = recording.root_recording || recording
      recordings = root.recordings_query(include_children: true, type: Terms.name).where(trashed_at: nil)
      return recordings if kind.blank?

      wanted = Terms.normalize_kind(kind)
      recordings.where(recordable_id: Terms.where(kind: wanted).select(:id))
    end
  end
end
