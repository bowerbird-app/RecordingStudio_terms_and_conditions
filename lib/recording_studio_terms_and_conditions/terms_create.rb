# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Drafts a Terms document on the shared library and seeds its outline.
  # Same path as Admin::TermsController#create.
  class TermsCreate
    class KindTaken < StandardError; end

    def self.call(actor:, title:, kind:, body: nil)
      new(actor: actor, title: title, kind: kind, body: body).call
    end

    def initialize(actor:, title:, kind:, body: nil)
      @actor = actor
      @title = title
      @kind = Terms.normalize_kind(kind)
      @body = body.to_s
    end

    def call
      raise KindTaken, KindPresence.blocked_message(kind) if KindPresence.exists?(kind: kind)

      recording = draft_recording
      Outline.seed_recording!(recording, actor: actor)
      recording
    end

    private

    attr_reader :actor, :title, :kind, :body

    def draft_recording
      parent.record(Terms, actor: actor, parent_recording: parent) do |terms|
        terms.title = title
        terms.body = body
        terms.kind = kind
      end
    end

    def parent
      RecordingStudioTermsAndConditions.library_root(actor: actor)
    end
  end
end
