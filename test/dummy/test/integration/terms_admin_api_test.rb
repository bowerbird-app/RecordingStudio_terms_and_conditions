# frozen_string_literal: true

require "test_helper"

class TermsAdminApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "admin-api-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @owner
    @workspace = Workspace.create!(name: "Admin API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @owner_access = bootstrap!(@root, @owner)
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    bootstrap!(@admin_root, @owner)
    @recording = record_terms(@root, title: "Studio Terms", body: "Be kind.", actor: @owner)
    publish_terms!(@recording, slug: "admin-api-#{SecureRandom.hex(4)}", actor: @owner)
    RecordingStudioTermsAndConditions::Outline.seed_recording!(@recording, actor: @owner)
    @token, @client = token_for(@owner_access)
    grant!(@admin_root, @client, :edit, @owner)
    grant!(@root, @client, :edit, @owner)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "admin client can edit a clause and release once" do
    listed = call(:get, "/workspaces/#{@root.id}/actions/terms_documents", @token)
    assert_response :success, response.body
    document = listed.fetch("documents").find { |row| row["id"] == @recording.id.to_s }
    assert_equal false, document.fetch("unreleased_changes")
    assert_equal true, document.fetch("live")

    outline = call(:get, "/terms/#{@recording.id}/actions/terms_outline", @token)
    clause_id = outline.dig("outline", "sections", 0, "clauses", 0, "id")
    section_id = outline.dig("outline", "sections", 0, "id")
    parent_snapshot = @recording.recordable_id
    events = []
    subscription = RecordingStudioTermsAndConditions::Published.subscribe { |event| events << event }

    call(:post, "/terms/#{@recording.id}/actions/terms_edit_clause", @token, { clause_id: clause_id, body: "Whisper." })
    assert_response :success, response.body
    assert_empty events
    assert_equal parent_snapshot, @recording.reload.recordable_id

    call(:post, "/terms/#{@recording.id}/actions/terms_add_section", @token, { heading: "Gear" })
    assert_response :success, response.body
    changes = call(:get, "/terms/#{@recording.id}/actions/terms_changes", @token)
    statuses = changes.fetch("changes").map { |change| [change["kind"], change["status"]] }
    assert_includes statuses, [ "clause", "changed" ]
    assert_includes statuses, [ "section", "added" ]

    preview = call(:get, "/terms/#{@recording.id}/actions/terms_preview", @token)
    assert_includes preview.dig("preview", "body"), "Whisper."
    assert_includes preview.dig("preview", "body"), "1.1"

    call(:post, "/terms/#{@recording.id}/actions/terms_release", @token, { title: "Studio Terms" })
    assert_response :success, response.body
    assert_equal true, json.dig("release", "released")
    assert_equal 1, events.size
    assert_includes json.dig("release", "body"), "Whisper."

    call(:post, "/terms/#{json.dig("release", "id")}/actions/terms_release", @token, { title: "Studio Terms" })
    assert_response :success, response.body
    assert_equal false, json.dig("release", "released")
    assert_equal 1, events.size
    assert section_id.present?
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  test "a client without admin access is forbidden" do
    outsider = User.create!(
      email: "outsider-api-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = outsider
    other = Workspace.create!(name: "Other #{SecureRandom.hex(4)}")
    other_root = RecordingStudio.root_recording_for(other)
    access = bootstrap!(other_root, outsider)
    token, = token_for(access, manager: outsider)

    call(:get, "/workspaces/#{other_root.id}/actions/terms_documents", token)
    assert_response :forbidden, response.body
  end

  test "read actions stay on view and writes require edit" do
    %i[public operations].each do |api|
      assert_equal :view, RecordingStudioApi.capability_action(:terms_outline, api: api).required_role
      assert_equal :edit, RecordingStudioApi.capability_action(:terms_release, api: api).required_role
      assert_equal :edit, RecordingStudioApi.capability_action(:terms_edit_clause, api: api).required_role
      refute RecordingStudioApi.capability_action(:terms_accept, api: api)
    end
  end

  private

  def bootstrap!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    raise result.error if result.respond_to?(:failure?) && result.failure?

    result.respond_to?(:value) ? result.value : result
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

  def token_for(access_recording, manager: @owner)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: manager,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
  end

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params: params, headers: headers(token), as: :json)
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
