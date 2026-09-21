# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Saves Terms copy. A live recording stays frozen; the edit becomes a new draft.
  class TermsWrite
    def self.call(recording:, actor:, title:, body:)
      new(recording: recording, actor: actor, title: title, body: body).call
    end

    def initialize(recording:, actor:, title:, body:)
      @recording = recording
      @actor = actor
      @title = title.to_s
      @body = body.to_s
    end

    def call
      return recording if live? && same_copy?

      live? ? fork_draft : revise_draft
    end

    private

    attr_reader :recording, :actor, :title, :body

    def live?
      recording.respond_to?(:currently_published?) && recording.currently_published?
    end

    def same_copy?
      terms = recording.recordable
      terms&.title.to_s == title && terms&.body.to_s == body
    end

    def revise_draft
      recording.root_recording.revise(recording, actor: actor) do |terms|
        terms.title = title
        terms.body = body
      end
    end

    def fork_draft
      parent = recording.parent_recording || recording.root_recording
      recording.root_recording.record(Terms, actor: actor, parent_recording: parent) do |terms|
        terms.title = title
        terms.body = body
      end
    end
  end
end
