# frozen_string_literal: true

require "test_helper"

class AuthorizeWriteTest < ActiveSupport::TestCase
  test "dummy authorize_write is Accessible edit, not actor presence" do
    initializer = File.read(Rails.root.join("config/initializers/recording_studio.rb"))

    assert_includes initializer, "config.authorize_write"
    assert_includes initializer, "RecordingStudioAccessible.authorized?"
    assert_includes initializer, "AccessCreationContext.allowed?"
    assert_includes initializer, "RecordingStudio::Access"
    refute_match(/authorize_write\s*=\s*->\(actor:, \*\*\) \{ actor\.present\? \}/, initializer)
  end

  test "AccessCreationContext allows only Access rows" do
    authorizer = RecordingStudio.configuration.authorize_write
    actor = recording_write_actor
    workspace = Workspace.create!(name: "Write policy #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    terms = RecordingStudioTermsAndConditions::Terms.new(title: "Policy", body: "No.")
    access = RecordingStudio::Access.new

    RecordingStudioAccessible::AccessCreationContext.allow do
      assert authorizer.call(actor: actor, root_recording: root_recording, recordable: access)
      refute authorizer.call(actor: actor, root_recording: root_recording, recordable: terms)
    end

    refute authorizer.call(actor: actor, root_recording: root_recording, recordable: terms)

    grant_write_access!(root_recording, actor)

    assert authorizer.call(actor: actor, root_recording: root_recording, recordable: terms)
  end
end
