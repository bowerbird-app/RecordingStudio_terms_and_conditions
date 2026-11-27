# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Saves Terms copy. A live recording stays frozen; the edit becomes a new draft.
  # A document that already has an outline must be edited as sections and clauses.
  class TermsWrite
    class OutlinePresent < StandardError; end

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
      refuse_outline!
      return recording if same_copy?
      raise OutlinePresent, outline_message if live? && outlined?

      live? ? fork_draft : revise_draft
    end

    private

    attr_reader :recording, :actor, :title, :body, :kind

    def live?
      recording.respond_to?(:currently_published?) && recording.currently_published?
    end

    def refuse_outline!
      return unless outlined?
      return if body == recording.recordable.body.to_s

      raise OutlinePresent, outline_message
    end

    def outlined?
      Outline.sections(recording).any?
    end

    def outline_message
      "This Terms document has an outline. Edit a section or a clause, then release."
    end

    def same_copy?
      terms = recording.recordable
      terms&.title.to_s == title &&
        terms&.body.to_s == body &&
        Terms.normalize_kind(terms&.kind) == source_kind
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
      end
    end

    def assign_fields(terms)
      terms.title = title
      terms.body = body
      terms.kind = source_kind
    end

    def source_kind
      Terms.normalize_kind(kind.presence || recording.recordable&.kind)
    end
  end
end
