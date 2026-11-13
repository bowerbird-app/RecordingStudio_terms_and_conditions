# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"

class LiveTermsEditKeepsAgreementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(
      email: "live-edit-admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @member = User.create!(
      email: "live-edit-member-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Live edit #{SecureRandom.hex(4)}")
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

  test "agreed member stays on ABC until admin publishes ABCDE" do
    sign_in @admin
    switch_to_workspace(@workspace)
    live = @root.record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Booth rules"
      terms.body = "Keep the door shut."
    end
    slug = "booth-rules-#{SecureRandom.hex(4)}"
    publish_terms!(live, slug: slug)
    RecordingStudioTermsAndConditions.accept!(@member, live, { "source" => "clickwrap" })
    publishable = live.publishable_child_recording

    switch_to_workspace(@admin_root)
    get recording_studio_terms_and_conditions.admin_term_sections_path(live)
    assert_response :success
    clause = RecordingStudioTermsAndConditions::Outline.sections(live.reload).first.clauses.first
    parent_snapshot = live.recordable_id
    assert_no_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count } do
      patch recording_studio_terms_and_conditions.admin_term_clause_path(live, clause.recording), params: {
        clause: { body: "Whisper in the booth." }
      }
    end

    live.reload
    assert_equal parent_snapshot, live.recordable_id
    assert live.currently_published?
    get "/terms/#{publishable.id}/#{slug}"
    assert_response :success
    assert_includes response.body, "Keep the door shut."
    refute_includes response.body, "Whisper in the booth."

    sign_in @member
    switch_to_workspace(@workspace)
    get "/"
    assert_response :success
    assert RecordingStudioTermsAndConditions.accepted?(@member, @workspace)
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@member, @workspace)

    sign_in @admin
    switch_to_workspace(@admin_root)
    post recording_studio_terms_and_conditions.release_admin_term_path(live), params: {
      terms: { title: "Booth rules" }
    }
    released = RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name)
                                         .order(:created_at).last
    released_publishable = released.reload.publishable_child_recording

    get "/terms/#{publishable.id}/#{slug}"
    assert_response :not_found
    get "/terms/#{released_publishable.id}/#{released.current_publishable.slug}"
    assert_response :success
    assert_includes response.body, "Whisper in the booth."
    refute_includes response.body, "Keep the door shut."

    sign_in @member
    switch_to_workspace(@workspace)
    get "/"
    assert_redirected_to recording_studio_terms_and_conditions.acceptance_path
    follow_redirect!
    assert_includes response.body, "Whisper in the booth."
    refute_includes response.body, "Keep the door shut."
    refute RecordingStudioTermsAndConditions.accepted?(@member, @workspace)
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@member, @workspace)
    assert_nil RecordingStudioTermsAndConditions::Acceptance.find_by(
      actor: @member,
      terms_recording_id: released.id,
      terms_id: released.recordable.id
    )
  end
end
