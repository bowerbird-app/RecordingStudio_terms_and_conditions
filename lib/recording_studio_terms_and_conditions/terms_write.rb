# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Saves Terms copy. A live recording stays frozen; the edit becomes a new draft.
  class TermsWrite
    def self.call(recording:, actor:, title:, body:, kind: nil)
      new(recording: recording, actor: actor, title: title, body: body, kind: kind).call
    end

    def initialize(recording:, actor:, title:, body:, kind: nil)
      @recording = recording
      @actor = actor
      @title = title.to_s
      @body = body.to_s
      @kind = kind
    end

    def call
      return recording if live? && same_copy?

      live? ? fork_draft : revise_draft
    end

    private

    attr_reader :recording, :actor, :title, :body, :kind

    def live?
      recording.respond_to?(:currently_published?) && recording.currently_published?
    end

    def same_copy?
      terms = recording.recordable
      terms&.title.to_s == title && terms&.body.to_s == body
    end

    def revise_draft
      recording.root_recording.revise(recording, actor: actor) do |terms|
        assign_fields(terms)
      end
    end

    def fork_draft
      parent = recording.parent_recording || recording.root_recording
      recording.root_recording.record(Terms, actor: actor, parent_recording: parent) do |terms|
        assign_fields(terms)
        terms.kind = source_kind
      end
    end

    def assign_fields(terms)
      terms.title = title
      terms.body = body
    end

    def source_kind
      Terms.normalize_kind(kind.presence || recording.recordable&.kind)
    end
  end
end
