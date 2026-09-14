# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminTermsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Admin write #{SecureRandom.hex(4)}")
    RecordingStudio.root_recording_for(@workspace)
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    unless RecordingStudioAccessible.authorized?(actor: @admin, recording: @admin_recording, role: :edit)
      bootstrap_owner_access!(@admin, @admin_recording)
    end
  end

  test "admin without access is forbidden" do
    sign_in @member

    get recording_studio_terms_and_conditions.admin_terms_path

    assert_response :forbidden
  end

  test "admin can draft and revise terms" do
    sign_in @admin
    switch_to_workspace(@workspace)

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_includes response.body, "Write terms"
    assert_includes response.body, "Title"
    assert_includes response.body, "Status"
    assert_includes response.body, "Agrees"
    assert_includes response.body, "Published"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "header.fp-top-nav", count: 1
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_select "a", text: "Sign out"
    assert_select "a[href='/users/sign_out']"
    assert_match %r{flat_pack/application}, response.body

    get recording_studio_terms_and_conditions.new_admin_term_path
    assert_response :success
    assert_includes response.body, "flat-pack--tiptap"
    assert_includes response.body, "terms[body]"

    assert_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count }, 1 do
      post recording_studio_terms_and_conditions.admin_terms_path, params: {
        terms: { title: "House rules", body: "No yelling in the booth." }
      }
    end

    recording = RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name)
                                          .order(:created_at).last
    assert_redirected_to recording_studio_terms_and_conditions.admin_term_path(recording)
    follow_redirect!
    assert_includes response.body, "Terms drafted. Publish when they are ready."
    assert_includes response.body, "House rules"
    assert_includes response.body, "flat-pack-content-editor-content"
    assert_includes response.body, "Publish"

    patch recording_studio_terms_and_conditions.admin_term_path(recording), params: {
      terms: { title: "House rules", body: "Whisper, please." }
    }

    assert_equal "Whisper, please.", recording.reload.recordable.body
    follow_redirect!
    assert_includes response.body, "Terms updated."

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_includes response.body, "House rules"
    assert_select "table thead th", text: "Title"
    assert_select "table thead th", text: "Status"
    assert_select "table thead th", text: "Published"
    assert_select "table thead th", text: "Agrees"
    assert_select "table thead th", text: "Open"
    assert_select "table tbody td a", text: "House rules"
    assert_select "table tbody td", text: "Draft"
    assert_select "table tbody td a", text: "Open"
  end

  test "admin section registers terms coverage widgets" do
    assert RecordingStudioAdmin.section_for("terms")
    assert RecordingStudioAdmin.screen_for("recording_studio_terms_acceptances")
    assert RecordingStudioAdmin.widget_for("widgets.terms.live")
    assert RecordingStudioAdmin.widget_for("widgets.terms.agrees")
    keys = AdminRoot.recording_studio_admin_section_keys_for(@admin_root, @admin_recording, nil)
    assert_includes keys, "terms"
  end

  test "recording studio admin terms hub is reachable and write parks there" do
    sign_in @admin
    switch_to_workspace(@admin_root)

    get "/admin"
    assert_response :success
    assert_includes response.body, "Write terms"
    assert_includes response.body, "Terms"
    assert_includes response.body, RecordingStudioTermsAndConditions.admin_write_path
  end
end
