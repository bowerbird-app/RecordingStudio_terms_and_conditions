# frozen_string_literal: true

begin
  require "recording_studio_moveable"
rescue LoadError
  nil
end

module RecordingStudioTermsAndConditions
  class Clause < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_clauses"

    recording_studio_recordable label: "Clause",
                                root: false,
                                allowed_parent_types: ["RecordingStudioTermsAndConditions::Section"]

    validates :body, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    include RecordingStudio::Capabilities::Moveable.to if defined?(RecordingStudio::Capabilities::Moveable)
  end
end
