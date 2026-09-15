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

  test "member cannot open Users receipts" do
    sign_in @admin
    switch_to_workspace(@workspace)
    recording = RecordingStudio.root_recording_for(@workspace).record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Quiet hours"
      terms.body = "Headphones after ten."
    end

    sign_in @member
    get recording_studio_terms_and_conditions.admin_term_users_path(recording)

    assert_response :forbidden
  end

  test "admin can draft and revise terms" do
    sign_in @admin
    switch_to_workspace(@workspace)

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_includes response.body, "Write terms"
    assert(
      response.body.include?("No terms yet") || response.body.include?("Title"),
      "expected an empty state or the Terms table"
    )
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
    assert_includes response.body, "Save draft"
    assert_select "div.inline-block button[type=submit]", text: "Save draft"

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
    assert_select "a", text: "Users"
    refute_includes response.body, "Who agreed"
    refute_includes response.body, "Nobody yet"

    get recording_studio_terms_and_conditions.admin_term_users_path(recording)
    assert_response :success
    assert_includes response.body, "Users"
    assert_includes response.body, "Nobody yet"

    RecordingStudioTermsAndConditions.accept!(@member, recording, { "source" => "clickwrap" })
    get recording_studio_terms_and_conditions.admin_term_users_path(recording)
    assert_response :success
    assert_includes response.body, @member.email
    refute_includes response.body, "Nobody yet"

    original_snapshot_id = recording.recordable_id
    assert_difference -> { RecordingStudioTermsAndConditions::Terms.count }, 1 do
      assert_no_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count } do
        patch recording_studio_terms_and_conditions.admin_term_path(recording), params: {
          terms: { title: "House rules", body: "Whisper, please." }
        }
      end
    end

    recording.reload
    refute_equal original_snapshot_id, recording.recordable_id
    assert_equal "Whisper, please.", recording.recordable.body
    follow_redirect!
    assert_includes response.body, "Terms updated."
    assert_includes response.body, "Recording #{recording.id}"
    assert_includes response.body, "snapshot #{recording.recordable_id}"

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

  test "admin terms index paginates like other kit tables" do
    sign_in @admin
    switch_to_workspace(@workspace)
    root = RecordingStudio.root_recording_for(@workspace)
    26.times do |index|
      root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |terms|
        terms.title = "Page #{index} #{SecureRandom.hex(3)}"
        terms.body = "Body #{index}."
      end
    end

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_select "table tbody tr", count: 25

    get recording_studio_terms_and_conditions.admin_terms_path, params: { page: 2 }
    assert_response :success
    page_two = css_select("table tbody tr").count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
  end

  test "term users paginates receipts" do
    sign_in @admin
    switch_to_workspace(@workspace)
    recording = RecordingStudio.root_recording_for(@workspace).record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Crowd"
      terms.body = "Many people tick this."
    end
    26.times do |index|
      person = User.create!(
        email: "agree-#{index}-#{SecureRandom.hex(3)}@example.com",
        password: "Password",
        password_confirmation: "Password"
      )
      RecordingStudioTermsAndConditions.accept!(person, recording, { "source" => "clickwrap" })
    end

    get recording_studio_terms_and_conditions.admin_term_users_path(recording)
    assert_response :success
    assert_select "table tbody tr", count: 25

    get recording_studio_terms_and_conditions.admin_term_users_path(recording), params: { page: 2 }
    assert_response :success
    page_two = css_select("table tbody tr").count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
  end

  test "admin terms screen table paginates" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    root = RecordingStudio.root_recording_for(@workspace)
    26.times do |index|
      root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |terms|
        terms.title = "Hub #{index} #{SecureRandom.hex(3)}"
        terms.body = "Hub body #{index}."
      end
    end

    get "/admin/screens/recording_studio_terms/table"
    assert_response :success
    assert_select "table tbody tr", count: 25

    get "/admin/screens/recording_studio_terms/table", params: { page: 2 }
    assert_response :success
    page_two = css_select("table tbody tr").count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
  end

  test "admin who agreed screen table paginates" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    recording = RecordingStudio.root_recording_for(@workspace).record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Crowd hub"
      terms.body = "Many people tick this."
    end
    26.times do |index|
      person = User.create!(
        email: "hub-agree-#{index}-#{SecureRandom.hex(3)}@example.com",
        password: "Password",
        password_confirmation: "Password"
      )
      RecordingStudioTermsAndConditions.accept!(person, recording, { "source" => "clickwrap" })
    end

    get "/admin/screens/recording_studio_terms_acceptances/table"
    assert_response :success
    assert_select "table tbody tr", count: 25

    get "/admin/screens/recording_studio_terms_acceptances/table", params: { page: 2 }
    assert_response :success
    page_two = css_select("table tbody tr").count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
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
