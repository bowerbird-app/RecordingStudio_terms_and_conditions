# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PublishableQuickActionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(
      email: "publish-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Publish #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    unless RecordingStudioAccessible.authorized?(actor: @admin, recording: @admin_recording, role: :edit)
      bootstrap_owner_access!(@admin, @admin_recording)
    end
    unless RecordingStudioAccessible.authorized?(actor: @admin, recording: @root, role: :edit)
      bootstrap_owner_access!(@admin, @root)
    end
  end

  test "term show publishes inline from QuickActions" do
    sign_in @admin
    switch_to_workspace(@workspace)
    recording = @root.record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Booth rules"
      terms.body = "Keep the door shut."
    end
    switch_to_workspace(@admin_root)

    get recording_studio_terms_and_conditions.admin_term_path(recording)
    assert_response :success
    assert_includes response.body, "Draft"
    assert_includes response.body, "Publish now"
    assert_includes response.body, "Preview"
    assert_match %r{/recordings/#{recording.id}/publishable/preview}, response.body
    refute_select "a", text: "Publish"

    patch "/recordings/#{recording.id}/publishable/publish",
          params: { inline: 1, button_size: "md" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "Published"
    assert recording.reload.currently_published?
  end

  test "preview is for people who can see the page and is not the public URL" do
    recording = record_terms(@root, title: "Quiet copy", body: "Whisper in the booth.")
    publish_terms!(recording, slug: "quiet-copy-#{SecureRandom.hex(4)}", status: "draft")

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: recording.id)
    assert_response :not_found

    sign_in @admin
    get recording_studio_publishable.preview_recording_publishable_path(recording_id: recording.id)
    assert_response :success
    assert_includes response.body, "Quiet copy"
    assert_includes response.body, "Whisper in the booth."
    assert_includes response.body, "Preview"
    assert_includes response.body, 'content="noindex,nofollow"'
  end

  test "live public terms do not show the Preview badge" do
    recording = record_terms(@root, title: "Live copy", body: "This is the public version.")
    publish_terms!(recording, slug: "live-copy-#{SecureRandom.hex(4)}")
    publishable = recording.publishable_child_recording

    get "/terms/#{publishable.id}/#{publishable.recordable.slug}"

    assert_response :success
    refute_includes response.body, ">Preview<"
    refute_includes response.body, 'content="noindex,nofollow"'
  end
end
