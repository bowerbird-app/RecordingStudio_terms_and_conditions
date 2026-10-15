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

  test "reaccepting_actors_for inside subscribe returns the v1 acceptor" do
    first = record_terms(title: "v1", body: "First.")
    publish_terms!(first, slug: "inside-#{SecureRandom.hex(4)}")
    actor = create_actor("inside")
    RecordingStudioTermsAndConditions.accept!(actor, first, source: "clickwrap")
    draft = RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: first,
      actor: actor,
      title: "v2",
      body: "Second."
    )
    found = nil

    inner = RecordingStudioTermsAndConditions::Published.subscribe do |event|
      found = RecordingStudioTermsAndConditions.reaccepting_actors_for(
        recording_id: event.payload.fetch(:recording_id),
        terms_id: event.payload.fetch(:terms_id)
      )
    end

    publish_terms!(draft, slug: "inside-v2-#{SecureRandom.hex(4)}")

    assert_equal [[actor.class.base_class.name, actor.id]], found
  ensure
    ActiveSupport::Notifications.unsubscribe(inner) if inner
  end

  test "scheduled go-live drafts the previous live row before the host query" do
    first = record_terms(title: "v1", body: "First.")
    publish_terms!(first, slug: "sched-#{SecureRandom.hex(4)}")
    actor = create_actor("sched")
    RecordingStudioTermsAndConditions.accept!(actor, first, source: "clickwrap")
    draft = RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: first,
      actor: actor,
      title: "v2",
      body: "Later."
    )
    publish_at = 1.hour.from_now.change(usec: 0)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: draft,
      attributes: { slug: "sched-v2-#{SecureRandom.hex(4)}", status: "published", publish_at: publish_at }
    ).value!

    found = nil
    inner = RecordingStudioTermsAndConditions::Published.subscribe do |event|
      found = RecordingStudioTermsAndConditions.reaccepting_actors_for(
        recording_id: event.payload.fetch(:recording_id),
        terms_id: event.payload.fetch(:terms_id)
      )
    end

    travel_to publish_at do
      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        draft.id.to_s,
        "publish",
        publish_at.iso8601
      )
      refute first.reload.currently_published?
      assert draft.reload.currently_published?
    end

    assert_equal [[actor.class.base_class.name, actor.id]], found
  ensure
    ActiveSupport::Notifications.unsubscribe(inner) if inner
  end

  test "a raising subscriber does not fail publish or skip SoleLive" do
    first = record_terms(title: "v1", body: "First.")
    publish_terms!(first, slug: "boom-#{SecureRandom.hex(4)}")
    actor = create_actor("boom")
    draft = RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: first,
      actor: actor,
      title: "v2",
      body: "Second."
    )
    reports = []
    boom = RecordingStudioTermsAndConditions::Published.subscribe do
      raise "subscriber boom"
    end

    result = with_error_reports(reports) do
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: draft,
        attributes: { slug: "boom-v2-#{SecureRandom.hex(4)}", status: "published" }
      )
    end

    assert_predicate result, :success?
    refute first.reload.currently_published?
    assert draft.reload.currently_published?
    assert(reports.any? { |error| error.message == "subscriber boom" })
  ensure
    ActiveSupport::Notifications.unsubscribe(boom) if boom
  end

  test "WindowTransitionJob retries the subscriber after a raise" do
    recording = record_terms(title: "Later", body: "Wait.")
    publish_at = 1.hour.from_now.change(usec: 0)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "retry-#{SecureRandom.hex(4)}", status: "published", publish_at: publish_at }
    ).value!
    @events.clear
    calls = 0
    reports = []
    boom = RecordingStudioTermsAndConditions::Published.subscribe do
      calls += 1
      raise "retry boom"
    end

    travel_to publish_at do
      with_error_reports(reports) do
        RecordingStudioPublishable::WindowTransitionJob.perform_now(
          recording.id.to_s,
          "publish",
          publish_at.iso8601
        )
        RecordingStudioPublishable::WindowTransitionJob.perform_now(
          recording.id.to_s,
          "publish",
          publish_at.iso8601
        )
      end
    end

    assert_equal 2, calls
    assert_equal 2, @events.size
    assert(reports.any? { |error| error.message == "retry boom" })
  ensure
    ActiveSupport::Notifications.unsubscribe(boom) if boom
  end

  test "a second successful WindowTransitionJob does not emit again" do
    recording = record_terms(title: "Later", body: "Wait.")
    publish_at = 1.hour.from_now.change(usec: 0)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "once-#{SecureRandom.hex(4)}", status: "published", publish_at: publish_at }
    ).value!
    @events.clear

    travel_to publish_at do
      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        recording.id.to_s,
        "publish",
        publish_at.iso8601
      )
      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        recording.id.to_s,
        "publish",
        publish_at.iso8601
      )
    end

    assert_equal 1, @events.size
  end

  test "a raising find_by does not emit the Terms event" do
    recording = record_terms(title: "v1", body: "First.")
    publish_terms!(recording, slug: "lookup-#{SecureRandom.hex(4)}")
    @events.clear
    reports = []

    with_error_reports(reports) do
      recordings = RecordingStudio::Recording.singleton_class
      original = recordings.instance_method(:find_by)
      recordings.define_method(:find_by) { |*| raise ActiveRecord::StatementInvalid, "lookup boom" }
      ActiveSupport::Notifications.instrument(
        "published.recording_studio_publishable",
        recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE,
        recording_id: recording.id,
        recordable_id: recording.recordable.id
      )
    ensure
      recordings.define_method(:find_by, original)
    end

    assert_empty @events
    assert(reports.any? { |error| error.message == "lookup boom" })
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

  def create_actor(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

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

  def with_error_reports(reports)
    reporter = Object.new
    reporter.define_singleton_method(:report) { |error, **_kwargs| reports << error }
    rails = Rails.singleton_class
    original = rails.instance_method(:error)
    rails.define_method(:error) { reporter }
    yield
  ensure
    rails.define_method(:error, original)
  end
end
