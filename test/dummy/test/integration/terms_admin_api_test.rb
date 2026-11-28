# frozen_string_literal: true

require "test_helper"

class TermsAdminApiTest < ActionDispatch::IntegrationTest
  OPERATIONS = "/recording_studio_api/apis/operations/v1"
  PUBLIC = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "admin-api-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @owner
    @workspace = Workspace.create!(name: "Admin API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: recording_write_actor)
    @owner_access = bootstrap_owner_access!(@owner, @root)
    @admin_root = RecordingStudio.create_root_recording!(AdminRoot.find_or_create_by!(name: "Admin"), actor: recording_write_actor)
    ensure_held_admin_on!(@admin_root, held_access_admin)
    grant!(@admin_root, @owner, :admin, held_access_admin)
    @recording = record_terms(@root, title: "Studio Terms", body: "Be kind.", actor: @owner)
    publish_terms!(@recording, slug: "admin-api-#{SecureRandom.hex(4)}", actor: @owner)
    RecordingStudioTermsAndConditions::Outline.seed_recording!(@recording, actor: @owner)
    @token, @client = token_for(@admin_root, role: :edit, api: :operations)
    @public_token, = public_token_for(@owner_access)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "admin client can edit a clause and release once" do
    listed = call(:get, "#{OPERATIONS}#{admin_root_path}/actions/terms_documents", @token)
    assert_response :success, response.body
    document = listed.fetch("documents").find { |row| row["id"] == @recording.id.to_s }
    assert_equal false, document.fetch("unreleased_changes")
    assert_equal true, document.fetch("live")

    outline = call(:get, "#{OPERATIONS}#{admin_root_path}/actions/terms_outline", @token, { terms_id: @recording.id })
    clause_id = outline.dig("outline", "sections", 0, "clauses", 0, "id")
    section_id = outline.dig("outline", "sections", 0, "id")
    parent_snapshot = @recording.recordable_id
    events = []
    subscription = RecordingStudioTermsAndConditions::Published.subscribe { |event| events << event }

    call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_edit_clause", @token, { terms_id: @recording.id, clause_id: clause_id, body: "Whisper." })
    assert_response :success, response.body
    assert_empty events
    assert_equal parent_snapshot, @recording.reload.recordable_id

    call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_add_section", @token, { terms_id: @recording.id, heading: "Gear" })
    assert_response :success, response.body
    changes = call(:get, "#{OPERATIONS}#{admin_root_path}/actions/terms_changes", @token, { terms_id: @recording.id })
    statuses = changes.fetch("changes").map { |change| [change["kind"], change["status"]] }
    assert_includes statuses, [ "clause", "changed" ]
    assert_includes statuses, [ "section", "added" ]

    preview = call(:get, "#{OPERATIONS}#{admin_root_path}/actions/terms_preview", @token, { terms_id: @recording.id })
    assert_includes preview.dig("preview", "body"), "Whisper."
    assert_includes preview.dig("preview", "body"), "1.1"

    call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_release", @token, { terms_id: @recording.id, title: "Studio Terms" })
    assert_response :success, response.body
    assert_equal true, json.dig("release", "released")
    assert_equal 1, events.size
    assert_includes json.dig("release", "body"), "Whisper."

    call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_release", @token, { terms_id: json.dig("release", "id"), title: "Studio Terms" })
    assert_response :unprocessable_entity, response.body
    assert_equal "invalid_input", json.dig("error", "code")
    assert_equal "No changes to release", json.dig("error", "message")
    assert_equal 1, events.size
    assert section_id.present?
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  test "operations terms_documents without admin-root access returns 403" do
    token, client = token_for(@root, role: :edit, api: :operations)
    refute RecordingStudioAccessible.authorized?(actor: client, recording: @admin_root, role: :view)

    call(:get, "#{OPERATIONS}/workspaces/#{@root.id}/actions/terms_documents", token)
    assert_forbidden_not_allowed
  end

  test "public API registers none of the authoring actions and operations registers all of them" do
    authoring = RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :operations).map(&:to_sym)
    clickwrap = RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public).map(&:to_sym)

    authoring.each do |name|
      assert RecordingStudioApi.capability_action(name, api: :operations), name.to_s
      refute RecordingStudioApi.capability_action(name, api: :public), name.to_s
    end
    clickwrap.each do |name|
      assert RecordingStudioApi.capability_action(name, api: :public), name.to_s
      assert RecordingStudioApi.capability_action(name, api: :operations), name.to_s
    end

    call(:get, "#{PUBLIC}/workspaces/#{@root.id}/actions/terms_documents", @public_token)
    assert_response :unprocessable_entity, response.body
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public), "terms_documents"
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public), "terms_release"
  end

  test "read actions stay on view and writes require edit" do
    assert_equal :view, RecordingStudioApi.capability_action(:terms_outline, api: :operations).required_role
    assert_equal :edit, RecordingStudioApi.capability_action(:terms_release, api: :operations).required_role
    assert_equal :edit, RecordingStudioApi.capability_action(:terms_edit_clause, api: :operations).required_role
    refute RecordingStudioApi.capability_action(:terms_outline, api: :public)
    refute RecordingStudioApi.capability_action(:terms_accept, api: :operations)
    refute RecordingStudioApi.capability_action(:terms_accept, api: :public)
  end

  private

  def admin_root_path
    "/admin_roots/#{@admin_root.id}"
  end
end
