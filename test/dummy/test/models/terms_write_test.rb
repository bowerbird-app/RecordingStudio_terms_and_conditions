# frozen_string_literal: true

require "test_helper"

class TermsWriteTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Write #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @actor = User.create!(
      email: "write-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  test "draft save revises the same recording" do
    recording = record_terms("Quiet", "Shh.")

    updated = RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: recording,
      actor: @actor,
      title: "Quieter",
      body: "Whisper."
    )

    assert_equal recording.id, updated.id
    assert_equal "Quieter", updated.recordable.title
    assert_equal "Whisper.", updated.recordable.body
    refute updated.currently_published?
  end

  test "live save forks a draft and leaves the published snapshot alone" do
    recording = record_terms("Booth", "ABC")
    publish_terms!(recording, slug: "booth-#{SecureRandom.hex(4)}")
    snapshot_id = recording.recordable_id

    draft = RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: recording,
      actor: @actor,
      title: "Booth",
      body: "ABCDE"
    )

    recording.reload
    assert_not_equal recording.id, draft.id
    assert_equal snapshot_id, recording.recordable_id
    assert_equal "ABC", recording.recordable.body
    assert recording.currently_published?
    assert_equal "ABCDE", draft.recordable.body
    refute draft.currently_published?
  end

  private

  def record_terms(title, body)
    @root.record(RecordingStudioTermsAndConditions::Terms, actor: @actor) do |terms|
      terms.title = title
      terms.body = body
    end
  end

  def publish_terms!(recording, slug:)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: "published" }
    ).value!
  end
end
