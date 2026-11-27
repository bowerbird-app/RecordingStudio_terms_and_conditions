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

  test "from AdminRoot staff can list create add section edit section edit clause and release" do
    kind = free_kind!
    created = call(:post, create_path, @edit_token, {
                     title: "Studio Terms",
                     kind: kind,
                     body: "Be kind."
                   })
    assert_response :success, response.body
    terms_id = created.dig("document", "id")

    listed = call(:get, "#{admin_root_path}/actions/terms_documents", @edit_token)
    assert_response :success, response.body
    assert listed.fetch("documents").any? { |row| row["id"] == terms_id }

    call(:post, "#{admin_root_path}/actions/terms_add_section", @edit_token, { terms_id: terms_id, heading: "Gear" })
    assert_response :success, response.body
    section_id = json.fetch("section").fetch("id")

    call(:post, "#{admin_root_path}/actions/terms_edit_section", @edit_token, {
           terms_id: terms_id, section_id: section_id, heading: "Rooms"
         })
    assert_response :success, response.body
    assert_equal "Rooms", json.dig("section", "heading")

    released = call(:post, "#{admin_root_path}/actions/terms_release", @edit_token, { terms_id: terms_id })
    assert_response :success, response.body
    assert_equal true, released.dig("release", "released")
    live_id = released.dig("release", "id")
    live = RecordingStudio::Recording.find(live_id)
    RecordingStudioTermsAndConditions.accept!(@acceptor, live.recordable)
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@acceptor)

    outline = call(:get, "#{admin_root_path}/actions/terms_outline", @edit_token, { terms_id: live_id })
    clause_id = outline.dig("outline", "sections", 0, "clauses", 0, "id")
    call(:post, "#{admin_root_path}/actions/terms_edit_clause", @edit_token, {
           terms_id: live_id, clause_id: clause_id, body: "Whisper."
         })
    assert_response :success, response.body

    again = call(:post, "#{admin_root_path}/actions/terms_release", @edit_token, { terms_id: live_id })
    assert_response :success, response.body
    assert_equal true, again.dig("release", "released")
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@acceptor)
    refute RecordingStudioTermsAndConditions.accepted?(@acceptor, kind: kind)
  end

  test "terms_create and terms_update register on operations only and accept stays off" do
    assert RecordingStudioApi.capability_action(:terms_create, api: :operations)
    assert RecordingStudioApi.capability_action(:terms_update, api: :operations)
    refute RecordingStudioApi.capability_action(:terms_create, api: :public)
    refute RecordingStudioApi.capability_action(:terms_update, api: :public)
    %i[public operations].each do |api|
      refute RecordingStudioApi.capability_action(:terms_accept_pending, api: api)
    end
  end

  private

  def admin_root_path
    "/admin_roots/#{@admin_root.id}"
  end

  def create_path
    "#{admin_root_path}/actions/terms_create"
  end

  def update_path
    "#{admin_root_path}/actions/terms_update"
  end

  def free_kind!
    kind = RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    RecordingStudioTermsAndConditions::KindPresence.recordings_for(kind: kind).each do |recording|
      recording.update_columns(trashed_at: Time.current)
    end
    kind
  end

  def assert_forbidden_not_allowed
    assert_response :forbidden, response.body
    assert_equal "forbidden", json.dig("error", "code")
    message = json.dig("error", "message").to_s.downcase
    assert message.include?("not authorized") || message.include?("not allowed") || message.include?("admin access"),
           message
  end

  def grant!(recording, actor, role, manager)
    configuration = nil
    original = nil
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)

    configuration = RecordingStudioAccessible.configuration
    original = configuration.access_management_authorizer
    configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: manager
    )
    raise result.error if result.respond_to?(:failure?) && result.failure?
  ensure
    configuration.access_management_authorizer = original if configuration && original
  end

  def token_for(access_point, role:, api:)
    configuration = RecordingStudioAccessible.configuration
    original = configuration.access_management_authorizer
    configuration.access_management_authorizer = ->(**) { true }
    provision = with_access_creation do
      RecordingStudioApi::Services::ProvisionApiClient.call(
        access_point_recording: access_point,
        manager_actor: @owner,
        role: role,
        name: "Client #{SecureRandom.hex(3)}",
        api: api
      )
    end
    raise provision.error unless provision.success?

    client = provision.value.fetch(:api_client)
    grant!(access_point, client, role, @owner)

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token),
      api: api
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), client]
  ensure
    configuration.access_management_authorizer = original if configuration && original
  end

  def with_access_creation(&)
    if defined?(RecordingStudioAccessible::AccessCreationContext)
      RecordingStudioAccessible::AccessCreationContext.allow(&)
    else
      yield
    end
  end

  def call(method, path, token, params = {})
    send(method, "#{OPERATIONS}#{path}", params: params, headers: headers(token), as: :json)
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def json
    JSON.parse(response.body)
  end
end
