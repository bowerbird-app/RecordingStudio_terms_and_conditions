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

  test "no-grant actor is denied Profile write on an unrelated root" do
    authorizer = RecordingStudio.configuration.authorize_write
    actor = User.create!(
      email: "no-grant-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    workspace = Workspace.create!(name: "Unrelated profile #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
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
    root_recording = RecordingStudio.root_recording_for(workspace)
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

  test "Users first Profile on People root needs Accessible edit" do
    authorizer = RecordingStudio.configuration.authorize_write
    actor = User.create!(
      email: "users-gap-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    people_root = RecordingStudioUser.people_root
    profile = RecordingStudioUser::Profile.new(
      user: actor,
      first_name: "Gap",
      last_name: "User",
      time_zone: "UTC"
    )

    refute authorizer.call(actor: actor, root_recording: people_root, recordable: profile)
    error = assert_raises(RecordingStudio::AuthorizationError) do
      people_root.record(RecordingStudioUser::Profile, actor: actor) do |row|
        row.user_id = actor.id
        row.first_name = "Gap"
        row.last_name = "User"
        row.time_zone = "UTC"
      end
    end
    assert_match(/denied/i, error.message)
  end
end
