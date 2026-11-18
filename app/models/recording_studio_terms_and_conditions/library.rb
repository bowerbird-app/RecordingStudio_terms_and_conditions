# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # App-level bucket for the one live Terms document per kind.
  # A shared root nobody owns.
  class Library < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_libraries"
    self.record_timestamps = false

    recording_studio_recordable label: "Terms library", root: true, shared: true

    before_create { self.created_at ||= Time.current }
  end
end
