# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class OutlineScreensTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(
      email: "outline-ui-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Outline UI #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    unless RecordingStudioAccessible.authorized?(actor: @admin, recording: @admin_recording, role: :edit)
      bootstrap_owner_access!(@admin, @admin_recording)
    end
    unless RecordingStudioAccessible.authorized?(actor: @admin, recording: @root, role: :edit)
      bootstrap_owner_access!(@admin, @root)
    end
    Current.actor = @admin
    sign_in @admin
    switch_to_workspace(@workspace)
    @recording = @root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |terms|
      terms.title = "Booth rules"
      terms.body = "Keep the door shut."
    end
    RecordingStudioTermsAndConditions::Outline.seed_recording!(@recording, actor: @admin)
    publish_terms!(@recording, slug: "booth-rules-#{SecureRandom.hex(4)}", actor: @admin)
    @recording.reload
    switch_to_workspace(@admin_root)
  end

  test "staff drill from the document into a clause and never see a clause title" do
    routes = recording_studio_terms_and_conditions
    section = RecordingStudioTermsAndConditions::Outline.sections(@recording).first
    clause = section.clauses.first

    get routes.admin_term_path(@recording)
    assert_response :success
    assert_includes response.body, "Current version"
    assert_includes response.body, "View full text"
    assert_includes response.body, "0 agreed"
    assert_select "a", text: "Edit"
    refute_includes response.body, "Edit sections"
    assert_includes response.body, "No unreleased changes"
    assert_select "a", text: "Review changes", count: 0
    assert_select "a", text: "Release", count: 0
    refute_includes response.body, "Publish now"
    refute_match(/agreed of \d+/, response.body)

    get routes.text_admin_term_path(@recording)
    assert_response :success
    assert_includes response.body, "The text people agree to."
    assert_includes response.body, "Keep the door shut."

    get routes.text_admin_term_path(@recording, version: "next")
    assert_response :success
    assert_includes response.body, "The next release."
    assert_includes response.body, "1.1"

    get routes.admin_term_sections_path(@recording)
    assert_response :success
    assert_includes response.body, "#{section.number}. #{section.heading}"
    assert_includes response.body, "1 clause"
    assert_includes response.body, "Reorder"
    assert_includes response.body, "moving_recording_id"
    assert_select "a", text: "Edit section name"
    assert_select "a", text: "Edit clauses"
    assert_select "button", text: "Delete"
    assert_includes response.body, "Remove this section?"
    assert_select ".fp-card"
    assert_includes response.body, "grid-cols-2"

    get routes.admin_term_section_path(@recording, section.recording)
    assert_response :success
    assert_includes response.body, "#{section.number}. #{section.heading}"
    assert_includes response.body, clause.number
    assert_includes response.body, "Keep the door shut."
    assert_includes response.body, "Add clause"
    assert_select "a", text: "Edit", count: 0
    refute_includes response.body, "edit_admin_term_section"
    refute_includes response.body, "section[heading]"
    refute_includes response.body, "Save heading"
    refute_includes response.body, "clause[title]"

    get routes.edit_admin_term_section_path(@recording, section.recording)
    assert_response :success
    assert_includes response.body, "section[heading]"
    assert_includes response.body, section.heading
    assert_select "button", text: "Save"
    assert_select "a", text: "Cancel"
    refute_includes response.body, "Add clause"

    get routes.admin_term_clause_path(@recording, clause.recording)
    assert_response :success
    assert_includes response.body, clause.number
    assert_includes response.body, "Keep the door shut."
    assert_includes response.body, "Remove this clause?"

    get routes.edit_admin_term_clause_path(@recording, clause.recording)
    assert_response :success
    assert_includes response.body, "clause[body]"
    refute_includes response.body, "clause[title]"
    refute_includes response.body, "Title"
  end

  test "saving a section heading returns to the section and stays unreleased" do
    routes = recording_studio_terms_and_conditions
    section = RecordingStudioTermsAndConditions::Outline.sections(@recording).first
    snapshot = @recording.recordable_id
    body = @recording.recordable.body

    patch routes.admin_term_section_path(@recording, section.recording), params: {
      section: { heading: "House rules" }
    }

    assert_redirected_to routes.admin_term_section_path(@recording, section.recording)
    follow_redirect!
    assert_includes response.body, "1. House rules"
    refute_includes response.body, "section[heading]"
    assert_equal snapshot, @recording.reload.recordable_id
    assert_equal body, @recording.recordable.body
    assert RecordingStudioTermsAndConditions::Outline.unreleased?(@recording)
    assert_equal "House rules", RecordingStudioTermsAndConditions::Outline.sections(@recording).first.heading

    patch routes.admin_term_section_path(@recording, section.recording), params: {
      section: { heading: "" }
    }

    assert_redirected_to routes.edit_admin_term_section_path(@recording, section.recording)
    assert_equal "House rules", RecordingStudioTermsAndConditions::Outline.sections(@recording).first.heading
  end

  test "reordering a section updates its number and leaves the live text alone" do
    routes = recording_studio_terms_and_conditions
    first = RecordingStudioTermsAndConditions::Outline.sections(@recording).first
    second = RecordingStudioTermsAndConditions::Outline.add_section(@recording, heading: "Gear", actor: @admin)
    snapshot = @recording.recordable_id
    body = @recording.recordable.body

    patch routes.admin_term_section_order_path(@recording),
          params: { moving_recording_id: second.id, target_position: 1 },
          as: :json

    assert_response :success
    assert_equal true, JSON.parse(response.body)["ok"]
    assert_equal snapshot, @recording.reload.recordable_id
    assert_equal body, @recording.recordable.body
    assert RecordingStudioTermsAndConditions::Outline.unreleased?(@recording)

    ordered = RecordingStudioTermsAndConditions::Outline.sections(@recording)
    assert_equal [second.id, first.recording.id], ordered.map { |section| section.recording.id }
    assert_equal "1", ordered.first.number

    get routes.admin_term_sections_path(@recording)
    assert_response :success
    assert_match(/1\.\s*Gear/, response.body)
    assert_includes response.body, "Changed"
  end

  test "reordering a clause updates its number inside the section" do
    routes = recording_studio_terms_and_conditions
    section = RecordingStudioTermsAndConditions::Outline.sections(@recording).first
    first = section.clauses.first
    second = RecordingStudioTermsAndConditions::Outline.add_clause(
      section.recording,
      body: "Leave the cables coiled.",
      actor: @admin
    )

    patch routes.admin_term_section_clause_order_path(@recording, section.recording),
          params: { moving_recording_id: second.id, target_position: 1 },
          as: :json

    assert_response :success
    assert_equal true, JSON.parse(response.body)["ok"]
    clauses = RecordingStudioTermsAndConditions::Outline.find_section!(@recording, section.recording.id).clauses
    assert_equal [second.id, first.recording.id], clauses.map { |clause| clause.recording.id }
    assert_equal "1.1", clauses.first.number
    refute_includes @recording.reload.recordable.body, "Leave the cables coiled."

    get routes.admin_term_sections_path(@recording)
    assert_response :success
    assert_includes response.body, "Changed"

    get routes.admin_term_section_path(@recording, section.recording)
    assert_response :success
    assert_includes response.body, "1.1"
    assert_includes response.body, "Leave the cables coiled."
  end

  test "agreement history numbers released snapshots in release order" do
    routes = recording_studio_terms_and_conditions
    first_person = User.create!(
      email: "first-#{SecureRandom.hex(3)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    RecordingStudioTermsAndConditions.accept!(first_person, @recording, { "source" => "clickwrap" })
    first_snapshot = @recording.recordable_id
    section = RecordingStudioTermsAndConditions::Outline.sections(@recording).first
    patch routes.admin_term_clause_path(@recording, section.clauses.first.recording), params: {
      clause: { body: "A later rule." }
    }
    post routes.release_admin_term_path(@recording)
    released = RecordingStudio::Recording.find(response.location.split("/").last)
    second_person = User.create!(
      email: "second-#{SecureRandom.hex(3)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    RecordingStudioTermsAndConditions.accept!(second_person, released, { "source" => "clickwrap" })

    get routes.admin_term_path(released)
    assert_response :success
    assert_includes response.body, "No unreleased changes"
    assert_includes response.body, "1 agreed"
    assert_match(/Version 2 · released \d{1,2} \w{3} \d{4}, \d{2}:\d{2}/, response.body)
    assert_select "a", text: "Release", count: 0
    assert_select "a", text: "Review changes", count: 0

    get routes.admin_term_users_path(released)
    assert_response :success
    assert_includes response.body, "Agreement history"
    assert_equal 2, response.body.scan("1 agreed").size
    assert response.body.index("Version 2") < response.body.index("Version 1")
    assert_includes response.body, "Live"

    get routes.admin_term_user_path(released, first_snapshot)
    assert_response :success
    assert_match(/Version 1 · released \d{1,2} \w{3} \d{4}, \d{2}:\d{2}/, response.body)
    refute_includes response.body, "Version 2"
    assert_includes response.body, first_person.email
    assert_match(/\d{4}, \d{2}:\d{2}/, response.body)
    refute_includes response.body, second_person.email

    get routes.admin_term_user_path(released, released.recordable_id)
    assert_response :success
    assert_match(/Version 2 · released \d{1,2} \w{3} \d{4}, \d{2}:\d{2}/, response.body)
    refute_includes response.body, "Version 1"
    assert_includes response.body, second_person.email
    refute_includes response.body, first_person.email
  end
end
