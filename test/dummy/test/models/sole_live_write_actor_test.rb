# frozen_string_literal: true

require "test_helper"

class SoleLiveWriteActorTest < ActiveSupport::TestCase
  test "write_actor_for uses Current.actor and does not fall back to event history" do
    actor = recording_write_actor
    root = RecordingStudio.root_recording_for(Workspace.create!(name: "Actor #{SecureRandom.hex(4)}"))
    grant_write_access!(root, actor)
    recording = root.record(RecordingStudioTermsAndConditions::Terms, actor: actor) do |terms|
      terms.title = "Live"
      terms.body = "History."
    end

    assert_equal actor, RecordingStudioTermsAndConditions::SoleLive.write_actor_for(recording)

    previous = Current.actor
    Current.actor = nil
    error = assert_raises(RecordingStudio::ActorRequired) do
      RecordingStudioTermsAndConditions::SoleLive.write_actor_for(recording)
    end
    assert_match(/actor is required/, error.message)
  ensure
    Current.actor = previous
  end
end
