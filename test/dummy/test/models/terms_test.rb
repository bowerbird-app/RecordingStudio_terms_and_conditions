# frozen_string_literal: true

require "test_helper"

class TermsTest < ActiveSupport::TestCase
  test "terms is a nested recordable with product label Terms" do
    declaration = RecordingStudio.recordable_declaration_for("RecordingStudioTermsAndConditions::Terms")

    assert_equal "Terms", declaration.label
    refute declaration.root?
    assert_equal ["Workspace"], RecordingStudio.allowed_parent_types_for(RecordingStudioTermsAndConditions::Terms)
    assert RecordingStudio.capability_enabled?(:publishable, for: RecordingStudioTermsAndConditions::Terms)
  end

  test "terms table is a snapshot without updated_at" do
    connection = ActiveRecord::Base.connection

    assert connection.table_exists?(:recording_studio_terms_and_conditions_terms)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :title)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :body)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :created_at)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :change_note)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :kind)
    refute connection.column_exists?(:recording_studio_terms_and_conditions_terms, :updated_at)
    refute connection.column_exists?(:recording_studio_terms_and_conditions_terms, :published)
  end

  test "terms can be recorded under a workspace and revised to a new snapshot" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Terms Workspace")))

    event = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioTermsAndConditions::Terms.new(title: "Studio terms", body: "Be kind."),
      root_recording: root_recording,
      parent_recording: root_recording
    )
    recording = event.recording
    original_terms = recording.recordable

    revised = root_recording.revise(recording) { |terms| terms.title = "Studio terms v2" }

    assert_equal root_recording, recording.parent_recording
    assert_kind_of RecordingStudioTermsAndConditions::Terms, original_terms
    assert_equal "Studio terms", original_terms.title
    refute_equal original_terms.id, revised.recordable.id
    assert_equal "Studio terms v2", revised.recordable.title
    assert_equal "Be kind.", revised.recordable.body
  end

  test "kind defaults to terms for new and existing rows" do
    terms = RecordingStudioTermsAndConditions::Terms.create!(title: "Studio terms", body: "Be kind.")

    assert_equal "terms", RecordingStudioTermsAndConditions::Terms.new.kind
    assert_equal "terms", terms.kind
    assert_equal "terms", RecordingStudioTermsAndConditions::Terms.find(terms.id).kind

    table = RecordingStudioTermsAndConditions::Terms.table_name
    id = SecureRandom.uuid
    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO #{table} (id, title, body, created_at)
      VALUES ('#{id}', 'Legacy terms', 'Old row.', NOW())
    SQL

    assert_equal "terms", RecordingStudioTermsAndConditions::Terms.find(id).kind
  end

  test "one Terms recording per kind per workspace" do
    first_root = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Kind Workspace")))
    other_root = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Other kind")))

    first = first_root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = "Studio terms"
      terms.body = "Be kind."
    end
    privacy = first_root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = "Privacy"
      terms.body = "Keep the tape."
      terms.kind = "privacy"
    end
    other = other_root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = "Other studio"
      terms.body = "Also kind."
    end

    assert_equal "terms", first.recordable.kind
    assert_equal "privacy", privacy.recordable.kind
    assert_equal "terms", other.recordable.kind

    error = assert_raises(ActiveRecord::RecordInvalid) do
      first_root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
        terms.title = "Second terms"
        terms.body = "Nope."
      end
    end
    assert_includes error.message, "This workspace already has Terms."

    revised = first_root.revise(first) { |terms| terms.body = "Be kinder." }
    assert_equal "terms", revised.recordable.kind
    assert_equal first.id, revised.id
  end

  test "terms cannot be created as a root" do
    terms = RecordingStudioTermsAndConditions::Terms.create!(title: "Orphan terms", body: "No.")

    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(terms)
    end
  end

  private

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
