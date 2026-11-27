# frozen_string_literal: true

require "test_helper"

class TermsAdminRootApiTest < ActionDispatch::IntegrationTest
  OPERATIONS = "/recording_studio_api/apis/operations/v1"

  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "admin-root-api-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @acceptor = User.create!(
      email: "acceptor-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @owner
    @admin_root = RecordingStudio.create_root_recording!(AdminRoot.find_or_create_by!(name: "Admin"), actor: recording_write_actor)
    grant!(@admin_root, @owner, :admin, held_access_admin)
    @edit_token, @edit_client = token_for(@admin_root, role: :edit, api: :operations)
    @view_token, @view_client = token_for(@admin_root, role: :view, api: :operations)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "create drafts a document and seeds an outline" do
    kind = free_kind!
    payload = call(:post, create_path, @edit_token, {
                     title: "Booth rules",
                     kind: kind,
                     body: "Keep the door shut."
                   })

    assert_response :success, response.body
    document = payload.fetch("document")
    outline = payload.fetch("outline")
    assert_equal "Booth rules", document.fetch("title")
    assert_equal kind, document.fetch("kind")
    refute_empty outline.fetch("sections")
    assert_equal document.fetch("id"), outline.fetch("id")
  end

  test "create requires body" do
    kind = free_kind!
    call(:post, create_path, @edit_token, { title: "No body", kind: kind })
    assert_response :unprocessable_entity, response.body
    assert_equal "invalid_input", json.dig("error", "code")
  end

  test "create refuses a kind that is not terms or privacy" do
    call(:post, create_path, @edit_token, { title: "G", kind: "garbage", body: "Body." })
    assert_response :unprocessable_entity, response.body
  end

  test "create refuses when that kind already exists" do
    kind = free_kind!
    call(:post, create_path, @edit_token, { title: "First", kind: kind, body: "One." })
    assert_response :success, response.body

    call(:post, create_path, @edit_token, { title: "Second", kind: kind, body: "Two." })
    assert_response :unprocessable_entity, response.body
    assert_equal "invalid_input", json.dig("error", "code")
    assert_includes json.dig("error", "message"), "already exists"
  end

  test "a view grant cannot create or update" do
    kind = free_kind!
    created = call(:post, create_path, @edit_token, { title: "Quiet hours", kind: kind, body: "Shh." })
    assert_response :success, response.body

    call(:post, create_path, @view_token, { title: "Nope", kind: kind, body: "No." })
    assert_forbidden_not_allowed

    call(:post, update_path, @view_token, { terms_id: created.dig("document", "id"), title: "Renamed" })
    assert_forbidden_not_allowed
  end

  test "terms_update changes title on an outlined draft and leaves kind and body" do
    kind = free_kind!
    created = call(:post, create_path, @edit_token, { title: "Draft one", kind: kind, body: "Hello world." })
    assert_response :success, response.body
    id = created.dig("document", "id")

    call(:post, update_path, @edit_token, { terms_id: id, title: "Renamed draft", kind: "terms_and_condition" })
    assert_response :success, response.body
    assert_equal "Renamed draft", json.dig("document", "title")
    assert_equal kind, json.dig("document", "kind")

    recording = RecordingStudio::Recording.find(id)
    assert_equal "Hello world.", recording.recordable.body
  end

  test "terms_update with a non-Terms or missing id is not found" do
    kind = free_kind!
    created = call(:post, create_path, @edit_token, { title: "S", kind: kind, body: "Body." })
    assert_response :success, response.body
    section_id = created.dig("outline", "sections", 0, "id")

    call(:post, update_path, @edit_token, { terms_id: section_id, title: "Hijack" })
    assert_response :not_found

    call(:post, update_path, @edit_token, { terms_id: SecureRandom.uuid, title: "Missing" })
    assert_response :not_found
  end

  test "from AdminRoot staff can list create add section edit section edit clause and release" do
    kind = free_kind!
    created = call(:post, create_path, @edit_token, {
                     title: "Studio Terms",
                     kind: kind,
                     body: "Be kind."
                   })
    assert_response :success, response.body
    terms_id = created.dig("document", "id")

    listed = call(:get, "#{OPERATIONS}#{admin_root_path}/actions/terms_documents", @edit_token)
    assert_response :success, response.body
    assert listed.fetch("documents").any? { |row| row["id"] == terms_id }

    call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_add_section", @edit_token, { terms_id: terms_id, heading: "Gear" })
    assert_response :success, response.body
    section_id = json.fetch("section").fetch("id")

    call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_edit_section", @edit_token, {
           terms_id: terms_id, section_id: section_id, heading: "Rooms"
         })
    assert_response :success, response.body
    assert_equal "Rooms", json.dig("section", "heading")

    released = call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_release", @edit_token, { terms_id: terms_id })
    assert_response :success, response.body
    assert_equal true, released.dig("release", "released")
    live_id = released.dig("release", "id")
    live = RecordingStudio::Recording.find(live_id)
    RecordingStudioTermsAndConditions.accept!(@acceptor, live.recordable)
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@acceptor)

    outline = call(:get, "#{OPERATIONS}#{admin_root_path}/actions/terms_outline", @edit_token, { terms_id: live_id })
    clause_id = outline.dig("outline", "sections", 0, "clauses", 0, "id")
    call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_edit_clause", @edit_token, {
           terms_id: live_id, clause_id: clause_id, body: "Whisper."
         })
    assert_response :success, response.body

    again = call(:post, "#{OPERATIONS}#{admin_root_path}/actions/terms_release", @edit_token, { terms_id: live_id })
    assert_response :success, response.body
    assert_equal true, again.dig("release", "released")
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@acceptor)
    refute RecordingStudioTermsAndConditions.accepted?(@acceptor, kind: kind)
  end

  test "terms_create and terms_update register on operations only and accept stays off" do
    authoring = RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :operations)
    authoring.each do |name|
      assert RecordingStudioApi.capability_action(name.to_sym, api: :operations), name
      refute RecordingStudioApi.capability_action(name.to_sym, api: :public), name
    end
    %i[public operations].each do |api|
      refute RecordingStudioApi.capability_action(:terms_accept_pending, api: api)
    end

    assert RecordingStudioTermsAndConditions::Api::AdminActions.create_fields[:body][:required]
  end

  private

  def admin_root_path
    "/admin_roots/#{@admin_root.id}"
  end

  def create_path
    "#{OPERATIONS}#{admin_root_path}/actions/terms_create"
  end

  def update_path
    "#{OPERATIONS}#{admin_root_path}/actions/terms_update"
  end
end
