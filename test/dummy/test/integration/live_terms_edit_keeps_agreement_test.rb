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
    unless RecordingStudioAccessible.authorized?(actor: @member, recording: @root, role: :view)
      bootstrap_owner_access!(@member, @root)
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
    patch recording_studio_terms_and_conditions.admin_term_path(live), params: {
      terms: { title: "Booth rules", body: "Whisper in the booth." }
    }
    draft = RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name)
                                      .order(:created_at).last
    assert_redirected_to recording_studio_terms_and_conditions.admin_term_path(draft)

    live.reload
    assert live.currently_published?
    refute draft.currently_published?
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
    publish_terms!(draft, slug: "booth-rules-v2-#{SecureRandom.hex(4)}")
    draft_publishable = draft.reload.publishable_child_recording

    get "/terms/#{publishable.id}/#{slug}"
    assert_response :not_found
    get "/terms/#{draft_publishable.id}/#{draft.current_publishable.slug}"
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
      terms_recording_id: draft.id,
      terms_id: draft.recordable.id
    )
  end
end
