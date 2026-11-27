# frozen_string_literal: true

require "test_helper"

class TermsOutlineTest < ActiveSupport::TestCase
  setup do
    @actor = User.create!(
      email: "outline-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @actor = library_writer(@actor)
    Current.actor = @actor
    @workspace = Workspace.create!(name: "Outline #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: recording_write_actor)
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
    unpublished = []
    unpublished_sub = ActiveSupport::Notifications.subscribe("unpublished.recording_studio_publishable") do
      unpublished << true
    end
    released = outline.release(recording, actor: @actor)
    assert_empty unpublished
    assert_equal 1, events.size
    assert_equal released.id.to_s, events.first.payload[:recording_id].to_s
    assert_equal released.recordable_id.to_s, events.first.payload[:terms_id].to_s
    assert_includes released.recordable.body, "<h2>1. House rules</h2>"
    assert_includes released.recordable.body, "1.1 Close the door."
    assert_includes released.recordable.body, "<h2>2. Gear</h2>"
    assert_includes released.recordable.body, "2.1 Coil the cables."
    assert released.currently_published?
    assert recording.reload.currently_published?
    assert_equal recording.id, released.id

    assert_no_difference -> { RecordingStudioTermsAndConditions::Terms.count } do
      assert_raises(RecordingStudioTermsAndConditions::Outline::Unchanged) do
        outline.release(released, actor: @actor)
      end
    end
    assert_equal 1, events.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    ActiveSupport::Notifications.unsubscribe(unpublished_sub) if defined?(unpublished_sub) && unpublished_sub
  end

  test "change detection ignores a revert and reports a delete" do
    recording = publish_seeded!("<h2>1. Room</h2><p>1.1 One</p><p>1.2 Two</p>")
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
    draft = terms_library.record(RecordingStudioTermsAndConditions::Terms, actor: @actor) do |terms|
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

  test "a live outline release stays on the lineage and refuses a no-op" do
    recording = publish_seeded!("MCP Tester seed.")
    outline = RecordingStudioTermsAndConditions::Outline
    lineage_id = recording.id
    outline.add_section(recording, heading: "Gear", actor: @actor)
    outline.add_clause(outline.sections(recording).last.recording, body: "Coil the cables.", actor: @actor)
    outline.add_section(recording, heading: "Rooms", actor: @actor)
    outline.add_clause(outline.sections(recording).last.recording, body: "Leave it tidy.", actor: @actor)

    assert_no_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count } do
      released = outline.release(recording, actor: @actor)
      assert_equal lineage_id, released.id
    end

    recording.reload
    headings = outline.sections(recording).map(&:heading)
    assert_equal [ "House rules", "Gear", "Rooms" ], headings
    refute headings.any? { |heading| heading.match?(/\A\d+\.\s/) }
    body = recording.recordable.body
    assert_includes body, "<h2>1. House rules</h2>"
    assert_includes body, "<h2>2. Gear</h2>"
    assert_includes body, "<h2>3. Rooms</h2>"
    refute_includes body, "1. 1."
    refute_includes body, "1.1 1.1"
    assert recording.currently_published?

    assert_raises(RecordingStudioTermsAndConditions::Outline::Unchanged) do
      outline.release(recording, actor: @actor)
    end
    assert_equal lineage_id, recording.reload.id
  end

  test "a wrapped single-block body keeps every section across two releases" do
    kind = RecordingStudioTermsAndConditions::Terms::DEFAULT_KIND
    RecordingStudioTermsAndConditions::KindPresence.recordings_for(kind: kind).each do |recording|
      recording.update_columns(trashed_at: Time.current)
    end
    body = "<div><h2>Scope</h2><p>Who this covers.</p><h2>Accounts</h2><p>Keep yours.</p>" \
           "<h2>Content</h2><p>Be decent.</p><h2>Ending</h2><p>We can stop.</p></div>"
    recording = record_terms(@root, title: "Studio terms", body: body, kind: kind, actor: @actor)
    publish_terms!(recording, slug: "wrapped-#{SecureRandom.hex(4)}", actor: @actor)
    outline = RecordingStudioTermsAndConditions::Outline
    lineage_id = recording.id
    assert outline.seed_recording!(recording, actor: @actor)

    recording.reload
    headings = outline.sections(recording).map(&:heading)
    assert_equal [ "Scope", "Accounts", "Content", "Ending" ], headings
    refute headings.any? { |heading| heading.match?(/\A\d+\.\s/) }
    refute outline.unreleased?(recording)
    error = assert_raises(RecordingStudioTermsAndConditions::Outline::Unchanged) do
      outline.release(recording, actor: @actor)
    end
    assert_equal "No changes to release", error.message

    outline.add_section(recording, heading: "Rooms", actor: @actor)
    outline.add_clause(outline.sections(recording).last.recording, body: "Leave it tidy.", actor: @actor)
    assert_no_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count } do
      released = outline.release(recording, actor: @actor)
      assert_equal lineage_id, released.id
    end

    published = recording.reload.recordable.body
    assert_includes published, "<h2>1. Scope</h2>"
    assert_includes published, "<h2>2. Accounts</h2>"
    assert_includes published, "<h2>3. Content</h2>"
    assert_includes published, "<h2>4. Ending</h2>"
    assert_includes published, "<h2>5. Rooms</h2>"
    refute_includes published, "1. 1."
    refute_includes published, "1.1 1.1"
    assert_equal 1, RecordingStudioTermsAndConditions::KindPresence.recordings_for(kind: recording.recordable.kind).size
    assert_equal lineage_id, recording.id
  end

  test "seeding a published body strips rendered numbers" do
    recording = record_terms(@root, title: "House rules", body: "<h2>1. House rules</h2><p>1.1 MCP Tester seed.</p>", actor: @actor)
    publish_terms!(recording, slug: "numbered-#{SecureRandom.hex(4)}", actor: @actor)
    outline = RecordingStudioTermsAndConditions::Outline

    assert outline.seed_recording!(recording, actor: @actor)
    section = outline.sections(recording.reload).first
    assert_equal "House rules", section.heading
    assert_equal "<p>MCP Tester seed.</p>", section.clauses.first.body
    refute outline.unreleased?(recording)

    assembled = outline.assemble(recording)
    assert_includes assembled, "<h2>1. House rules</h2>"
    refute_includes assembled, "1. 1."
    refute_includes assembled, "1.1 1.1"
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

  test "author writes keep numeric text that is not the generated outline number" do
    recording = publish_seeded!("Be kind in the booth.")
    outline = RecordingStudioTermsAndConditions::Outline
    outline.add_section(recording, heading: "2026. Policy", actor: @actor)
    section = outline.sections(recording).last
    outline.add_clause(section.recording, body: "1.5 times the monthly fee", actor: @actor)
    outline.add_clause(section.recording, body: "2.5 hours", actor: @actor)

    section = outline.sections(recording.reload).last
    assert_equal "2026. Policy", section.heading
    assert_equal [ "1.5 times the monthly fee", "2.5 hours" ], section.clauses.map(&:body)
  end

  test "seeding keeps numeric clause text that is not that clause's generated number" do
    body = "<h2>2026. Policy</h2><p>1.5 times the monthly fee</p><p>2.5 hours</p>"
    recording = record_terms(@root, title: "Fees", body: body, actor: @actor)
    outline = RecordingStudioTermsAndConditions::Outline
    assert outline.seed_recording!(recording, actor: @actor)
    section = outline.sections(recording.reload).first
    assert_equal "2026. Policy", section.heading
    assert_equal [ "<p>1.5 times the monthly fee</p>", "<p>2.5 hours</p>" ], section.clauses.map(&:body)
  end

  test "seeding again strips stored generated numbers on an existing outline" do
    recording = publish_seeded!("Who this covers.")
    outline = RecordingStudioTermsAndConditions::Outline
    snapshot = recording.recordable_id
    live_body = "<h2>1. 1. Scope</h2><p>1.1 1.1 Who this covers.</p>"
    section = outline.sections(recording).first
    outline.edit_section(section.recording, heading: "1. Scope", actor: @actor)
    outline.edit_clause(section.clauses.first.recording, body: "<p>1.1 Who this covers.</p>", actor: @actor)
    RecordingStudioTermsAndConditions::Terms.where(id: recording.recordable_id).update_all(body: live_body)
    recording.reload

    assert outline.seed_recording!(recording, actor: @actor)
    section = outline.sections(recording.reload).first
    assert_equal "Scope", section.heading
    assert_equal "<p>Who this covers.</p>", section.clauses.first.body
    assert_equal live_body, recording.recordable.body
    assert_equal snapshot, recording.recordable_id
    assert outline.unreleased?(recording)
    assert_nil outline.seed_recording!(recording, actor: @actor)

    released = outline.release(recording, actor: @actor)
    assert_equal live_body, RecordingStudioTermsAndConditions::Terms.find(snapshot).body
    refute_equal snapshot, released.recordable_id
    refute_includes released.recordable.body, "1. 1."
    assert_includes released.recordable.body, "<h2>1. Scope</h2>"
  end

  test "repair and release with a pending edit leave the live snapshot in place" do
    recording = publish_seeded!("Who this covers.")
    outline = RecordingStudioTermsAndConditions::Outline
    snapshot = recording.recordable_id
    live_body = "<h2>1. 1. Scope</h2><p>1.1 1.1 Who this covers.</p>"
    section = outline.sections(recording).first
    outline.edit_section(section.recording, heading: "1. Scope", actor: @actor)
    outline.edit_clause(section.clauses.first.recording, body: "<p>1.1 Whisper, please.</p>", actor: @actor)
    RecordingStudioTermsAndConditions::Terms.where(id: recording.recordable_id).update_all(body: live_body)
    recording.reload

    assert outline.seed_recording!(recording, actor: @actor)
    assert_equal live_body, recording.reload.recordable.body
    assert_equal snapshot, recording.recordable_id
    assert outline.unreleased?(recording)

    outline.seed_all!(actor: @actor)
    assert_equal live_body, recording.reload.recordable.body
    assert_equal snapshot, recording.recordable_id

    released = outline.release(recording, actor: @actor)
    assert_equal live_body, RecordingStudioTermsAndConditions::Terms.find(snapshot).body
    refute_equal snapshot, released.recordable_id
    assert_includes released.recordable.body, "Whisper, please."
    refute_includes released.recordable.body, "1. 1."
  end

  test "a publish-settings update on a live seeded document keeps the version and applies the slug" do
    recording = publish_seeded!("Be kind in the booth.")
    outline = RecordingStudioTermsAndConditions::Outline
    refute outline.unreleased?(recording)
    snapshot = recording.recordable_id
    slug = "settings-#{SecureRandom.hex(4)}"

    assert_no_difference -> { RecordingStudioTermsAndConditions::Terms.count } do
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: recording,
        attributes: { slug: slug, status: "published" },
        actor: @actor
      ).value!
    end

    recording.reload
    assert_equal snapshot, recording.recordable_id
    assert_equal slug, recording.current_publishable.slug
    refute outline.unreleased?(recording)
    assert recording.currently_published?
  end

  private

  def publish_seeded!(body)
    writer = library_writer(@actor)
    recording = record_terms(@root, title: "House rules", body: body, actor: writer)
    publish_terms!(recording, slug: "house-#{SecureRandom.hex(4)}", actor: writer)
    RecordingStudioTermsAndConditions::Outline.seed_recording!(recording, actor: writer)
    recording.reload
  end

  def subscribe(&block)
    RecordingStudioTermsAndConditions::Published.subscribe(&block)
  end
end
