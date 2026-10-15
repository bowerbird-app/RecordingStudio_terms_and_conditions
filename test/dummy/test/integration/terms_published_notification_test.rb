# frozen_string_literal: true

require "test_helper"

class TermsPublishedNotificationTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Notify #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @events = []
    @subscriber = RecordingStudioTermsAndConditions::Published.subscribe do |event|
      @events << event.payload
    end
  end

  teardown do
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
  end

  test "publishing live Terms emits recording_id and terms_id after commit" do
    recording = record_terms(title: "v1", body: "First.")
    publish_terms!(recording, slug: "notify-#{SecureRandom.hex(4)}")

    assert_equal 1, @events.size
    assert_equal(
      { recording_id: recording.id, terms_id: recording.recordable.id },
      @events.first
    )
  end

  test "scheduled window go-live emits the same event" do
    recording = record_terms(title: "Later", body: "Wait.")
    publish_at = 1.hour.from_now.change(usec: 0)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "later-#{SecureRandom.hex(4)}", status: "published", publish_at: publish_at }
    ).value!

    assert_empty @events

    travel_to publish_at do
      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        recording.id.to_s,
        "publish",
        publish_at.iso8601
      )
    end

    assert_equal 1, @events.size
    assert_equal recording.id, @events.first.fetch(:recording_id)
    assert_equal recording.recordable.id, @events.first.fetch(:terms_id)
  end

  test "TermsWrite fork and accept! emit nothing" do
    recording = record_terms(title: "Live", body: "ABC")
    publish_terms!(recording, slug: "fork-#{SecureRandom.hex(4)}")
    @events.clear
    actor = User.create!(
      email: "notify-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )

    RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: recording,
      actor: actor,
      title: "Live",
      body: "ABCDE"
    )
    RecordingStudioTermsAndConditions.accept!(actor, recording, source: "clickwrap")

    assert_empty @events
  end

  test "SoleLive draft of the previous live emits no second Terms event" do
    first = record_terms(title: "v1", body: "First.")
    publish_terms!(first, slug: "sole-#{SecureRandom.hex(4)}")
    draft = RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: first,
      actor: User.create!(
        email: "sole-#{SecureRandom.hex(4)}@example.com",
        password: "Password",
        password_confirmation: "Password"
      ),
      title: "v2",
      body: "Second."
    )
    @events.clear
    publish_terms!(draft, slug: "sole-v2-#{SecureRandom.hex(4)}")

    assert_equal 1, @events.size
    assert_equal draft.id, @events.first.fetch(:recording_id)
    assert_equal draft.recordable.id, @events.first.fetch(:terms_id)
  end

  private

  def record_terms(title:, body:)
    @root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
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
