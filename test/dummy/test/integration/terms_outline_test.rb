# frozen_string_literal: true

require "test_helper"

class TermsOutlineTest < ActiveSupport::TestCase
  setup do
    @actor = User.create!(
      email: "outline-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @actor
    @workspace = Workspace.create!(name: "Outline #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_write_access!(@root, @actor)
  end

  teardown do
    Current.actor = nil
  end

  test "a clause edit does not version the parent or fire the hook" do
    recording = publish_seeded!("Be kind in the booth.")
    parent_snapshot = recording.recordable_id
    events = []
    subscription = subscribe { |event| events << event }

    clause = RecordingStudioTermsAndConditions::Outline.sections(recording).first.clauses.first
    RecordingStudioTermsAndConditions::Outline.edit_clause(clause.recording, body: "Whisper.", actor: @actor)

    assert_empty events
    assert_equal parent_snapshot, recording.reload.recordable_id
    assert_equal "Be kind in the booth.", recording.recordable.body
    assert RecordingStudioTermsAndConditions::Outline.unreleased?(recording)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  test "several edits release once and the hook fires once" do
    recording = publish_seeded!("Keep the door shut.")
    events = []
    subscription = subscribe { |event| events << event }
    outline = RecordingStudioTermsAndConditions::Outline
    section = outline.sections(recording).first
    outline.edit_clause(section.clauses.first.recording, body: "Close the door.", actor: @actor)
    outline.add_section(recording, heading: "Gear", actor: @actor)
    outline.add_clause(outline.sections(recording).last.recording, body: "Coil the cables.", actor: @actor)

    assert_empty events
    released = outline.release(recording, actor: @actor)
    assert_equal 1, events.size
    assert_equal released.id.to_s, events.first.payload[:recording_id].to_s
    assert_equal released.recordable_id.to_s, events.first.payload[:terms_id].to_s
    assert_includes released.recordable.body, "<h2>1. House rules</h2>"
    assert_includes released.recordable.body, "1.1 Close the door."
    assert_includes released.recordable.body, "<h2>2. Gear</h2>"
    assert_includes released.recordable.body, "2.1 Coil the cables."
    assert released.currently_published?
    refute recording.reload.currently_published?

    assert_no_difference -> { RecordingStudioTermsAndConditions::Terms.count } do
      assert_equal released.id, outline.release(released, actor: @actor).id
    end
    assert_equal 1, events.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  test "change detection ignores a revert and reports a delete" do
    recording = publish_seeded!("<h2>Room</h2><p>One</p><p>Two</p>")
    outline = RecordingStudioTermsAndConditions::Outline
    clauses = outline.sections(recording).first.clauses
    original = clauses.first.body
    outline.edit_clause(clauses.first.recording, body: "Changed", actor: @actor)
    assert outline.changes(recording).any? { |change| change.status == "changed" && change.kind == "clause" }

    outline.edit_clause(clauses.first.recording.reload, body: original, actor: @actor)
    assert_empty outline.changes(recording)
    refute outline.unreleased?(recording)

    outline.remove_clause(clauses.last.recording, actor: @actor)
    removed = outline.changes(recording).select { |change| change.kind == "clause" && change.status == "removed" }
    assert_equal 1, removed.size
    assert outline.unreleased?(recording)
  end

  test "numbers follow order and ids stay put when a section moves" do
    recording = publish_seeded!("First line.")
    outline = RecordingStudioTermsAndConditions::Outline
    first = outline.sections(recording).first
    outline.add_section(recording, heading: "Second", actor: @actor)
    outline.add_clause(outline.sections(recording).last.recording, body: "Later.", actor: @actor)
    moved_id = first.id
    outline.move_section(first.recording, to_index: 1, actor: @actor)

    sections = outline.sections(recording.reload)
    assert_equal [ "1", "2" ], sections.map(&:number)
    assert_equal "Second", sections.first.heading
    assert_equal moved_id, sections.last.id
    assert_equal "2.1", sections.last.clauses.first.number
    assert outline.changes(recording).any? { |change| change.kind == "section" && change.status == "moved" }
  end

  test "accept stays live only and idempotent" do
    recording = publish_seeded!("Agreed copy.")
    draft = @root.record(RecordingStudioTermsAndConditions::Terms, actor: @actor) do |terms|
      terms.title = "Draft"
      terms.body = "Not live."
    end

    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      assert_raises(RecordingStudioTermsAndConditions::NotLive) do
        RecordingStudioTermsAndConditions.accept!(@actor, draft, { "source" => "clickwrap" })
      end
    end

    first = RecordingStudioTermsAndConditions.accept!(@actor, recording, { "source" => "clickwrap" })
    second = nil
    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      second = RecordingStudioTermsAndConditions.accept!(@actor, recording, { "source" => "clickwrap" })
    end
    assert_equal first.id, second.id
  end

  test "seeding is idempotent and leaves the parent version and receipts alone" do
    recording = publish_seeded!("<h2>Welcome</h2><p>Read this.</p><ul><li>Be on time.</li></ul>")
    RecordingStudioTermsAndConditions.accept!(@actor, recording, { "source" => "clickwrap" })
    snapshot = recording.recordable_id
    body = recording.recordable.body
    receipt_ids = RecordingStudioTermsAndConditions::Acceptance.order(:id).pluck(:id)
    outline = RecordingStudioTermsAndConditions::Outline

    assert_nil outline.seed_recording!(recording, actor: @actor)
    assert_equal 1, outline.sections(recording).size
    assert_equal [ "Read this.", "Be on time." ], outline.sections(recording).first.clauses.map { |clause| clause.recording.recordable.body.gsub(/<[^>]+>/, "").strip }
    # The publish helper did not seed. Seed now, then again.
    bare = record_terms(@root, title: "Bare", body: "One paragraph.\n\nTwo paragraphs.", actor: @actor)
    publish_terms!(bare, slug: "bare-#{SecureRandom.hex(4)}", actor: @actor)
    bare_snapshot = bare.recordable_id
    assert outline.seed_recording!(bare, actor: @actor)
    assert_nil outline.seed_recording!(bare, actor: @actor)
    assert_equal bare_snapshot, bare.reload.recordable_id
    assert_equal "One paragraph.\n\nTwo paragraphs.", bare.recordable.body
    assert bare.recordable.release_manifest.present?
    refute outline.unreleased?(bare)
    assert_equal receipt_ids, RecordingStudioTermsAndConditions::Acceptance.order(:id).pluck(:id)
    assert_equal snapshot, recording.reload.recordable_id
    assert_equal body, recording.recordable.body
    Rails.application.load_tasks
    assert Rake::Task.task_defined?("recording_studio_terms_and_conditions:seed_outline")
  end

  private

  def publish_seeded!(body)
    recording = record_terms(@root, title: "House rules", body: body, actor: @actor)
    publish_terms!(recording, slug: "house-#{SecureRandom.hex(4)}", actor: @actor)
    RecordingStudioTermsAndConditions::Outline.seed_recording!(recording, actor: @actor)
    recording.reload
  end

  def subscribe(&block)
    RecordingStudioTermsAndConditions::Published.subscribe(&block)
  end
end
