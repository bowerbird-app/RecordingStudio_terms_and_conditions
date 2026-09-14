# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Append-only clickwrap receipt. Not a recordable and not on the Recording tree.
  class Acceptance < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_acceptances"

    belongs_to :actor, polymorphic: true

    validates :actor_type, :actor_id, :terms_recording_id, :terms_id, :accepted_at, presence: true

    def provenance
      super.presence || {}
    end

    def readonly?
      persisted?
    end
  end
end
