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

  test "terms table is a snapshot with kind and without updated_at" do
    connection = ActiveRecord::Base.connection

    assert connection.table_exists?(:recording_studio_terms_and_conditions_terms)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :title)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :body)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :kind)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_terms, :created_at)
    refute connection.column_exists?(:recording_studio_terms_and_conditions_terms, :change_note)
    refute connection.column_exists?(:recording_studio_terms_and_conditions_terms, :category)
    refute connection.column_exists?(:recording_studio_terms_and_conditions_terms, :updated_at)
    refute connection.column_exists?(:recording_studio_terms_and_conditions_terms, :published)
  end

  test "kind defaults to terms_and_condition and rejects unknown values" do
    terms = RecordingStudioTermsAndConditions::Terms.new(title: "Studio", body: "Be kind.")
    assert_equal "terms_and_condition", terms.kind
    assert terms.valid?

    terms.kind = "usage"
    refute terms.valid?
    assert_includes terms.errors[:kind], "is not included in the list"
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
