# frozen_string_literal: true

begin
  require "recording_studio_moveable"
rescue LoadError
  nil
end

module RecordingStudioTermsAndConditions
  class Section < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_sections"

    recording_studio_recordable label: "Section",
                                root: false,
                                allowed_parent_types: ["RecordingStudioTermsAndConditions::Terms"]

    validates :heading, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    include RecordingStudio::Capabilities::Moveable.to if defined?(RecordingStudio::Capabilities::Moveable)
  end
end
