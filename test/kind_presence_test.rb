# frozen_string_literal: true

require "test_helper"

class KindPresenceTest < Minitest::Test
  def test_recordings_for_returns_empty_when_root_lookup_fails
    root = Struct.new(:id).new("workspace-1")
    logs = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message| logs << message.to_s }

    RecordingStudio.stub(:root_recording_for, ->(*) { raise ArgumentError, "recordable must be persisted" }) do
      Rails.stub(:logger, logger) do
        assert_equal [], RecordingStudioTermsAndConditions::KindPresence.recordings_for(
          root,
          kind: "terms_and_condition"
        )
        refute RecordingStudioTermsAndConditions::KindPresence.exists?(root, kind: "terms_and_condition")
      end
    end

    assert logs.any? { |line| line.include?("kind presence root skipped") && line.include?("ArgumentError") }
  end
end
