# frozen_string_literal: true

require "test_helper"

class AuthorizeWriteTest < ActiveSupport::TestCase
  test "dummy authorize_write is Accessible edit, not actor presence" do
    initializer = File.read(Rails.root.join("config/initializers/recording_studio.rb"))

    assert_includes initializer, "config.authorize_write"
    assert_includes initializer, "RecordingStudioAccessible.authorized?"
    assert_includes initializer, "AccessCreationContext.allowed?"
    assert_includes initializer, "RecordingStudio::Access"
    assert_includes initializer, ":admin"
    refute_includes initializer, "actor.is_a?(User)"
    refute_match(/authorize_write\s*=\s*->\(actor:, \*\*\) \{ actor\.present\? \}/, initializer)
    assert_includes initializer, "root_recording.nil?"
  end

  test "a present actor may create a root and a blank actor may not" do
    authorizer = RecordingStudio.configuration.authorize_write
    actor = recording_write_actor
    workspace = Workspace.new(name: "New root #{SecureRandom.hex(4)}")

    assert authorizer.call(actor: actor, root_recording: nil, recordable: workspace)
    refute authorizer.call(actor: nil, root_recording: nil, recordable: workspace)
  end

  test "AccessCreationContext allows only Access rows" do
    authorizer = RecordingStudio.configuration.authorize_write
    actor = recording_write_actor
    workspace = Workspace.create!(name: "Write policy #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: recording_write_actor)
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

  test "no-grant actor is denied Profile write on an unrelated root" do
    authorizer = RecordingStudio.configuration.authorize_write
    actor = User.create!(
      email: "no-grant-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    workspace = Workspace.create!(name: "Unrelated profile #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: recording_write_actor)
    profile = RecordingStudioUser::Profile.new(
      user: actor,
      first_name: "No",
      last_name: "Grant",
      time_zone: "UTC"
    )

    refute authorizer.call(actor: actor, root_recording: root_recording, recordable: profile)
  end

  test "edit-only grantee is denied Access write outside AccessCreationContext" do
    authorizer = RecordingStudio.configuration.authorize_write
    admin = recording_write_actor
    editor = User.create!(
      email: "edit-only-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    workspace = Workspace.create!(name: "Edit-only access #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: recording_write_actor)
    grant_write_access!(root_recording, admin)
    result = RecordingStudioAccessible.grant_access(
      recording: root_recording,
      actor: editor,
      role: :edit,
      manager_actor: admin
    )
    raise result.error if result.respond_to?(:failure?) && result.failure?

    access = RecordingStudio::Access.new

    refute RecordingStudioAccessible::AccessCreationContext.allowed?
    refute authorizer.call(actor: editor, root_recording: root_recording, recordable: access)
    assert authorizer.call(actor: editor, root_recording: root_recording, recordable:
      RecordingStudioTermsAndConditions::Terms.new(title: "Edit ok", body: "Yes."))
  end

  test "a person may record their own Profile on the People root" do
    authorizer = RecordingStudio.configuration.authorize_write
    actor = User.create!(
      email: "own-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    other = User.create!(
      email: "other-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    people = RecordingStudioUser::People.first || RecordingStudioUser::People.create!
    people_root = RecordingStudio.root_recording_for(people) ||
                  RecordingStudio.create_root_recording!(people, actor: recording_write_actor)
    own = RecordingStudioUser::Profile.new(
      user: actor,
      first_name: "Own",
      last_name: "Profile",
      time_zone: "UTC"
    )
    theirs = RecordingStudioUser::Profile.new(
      user: other,
      first_name: "Other",
      last_name: "Profile",
      time_zone: "UTC"
    )

    assert authorizer.call(actor: actor, root_recording: people_root, recordable: own)
    refute authorizer.call(actor: actor, root_recording: people_root, recordable: theirs)

    recording = people_root.record(RecordingStudioUser::Profile, actor: actor) do |row|
      row.user_id = actor.id
      row.first_name = "Own"
      row.last_name = "Profile"
      row.time_zone = "UTC"
    end

    assert_equal actor.id, recording.recordable.user_id
  end
end
