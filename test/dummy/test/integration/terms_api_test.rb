# frozen_string_literal: true

require "test_helper"

class TermsApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = user("owner")
    Current.actor = @owner
    @workspace = Workspace.create!(name: "API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @owner_access = bootstrap!(@root, @owner)
    @token = token_for(@owner_access)
    @recording = record_terms(@root, title: "Studio Terms", body: "Be kind.", actor: @owner)
    publish_terms!(@recording, slug: "studio-terms-#{SecureRandom.hex(4)}", actor: @owner)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "grant actor can read pending current and accepted then accept pending" do
    pending = call(:get, "/workspaces/#{@root.id}/actions/pending_published_list", @token)
    assert_response :success, response.body
    assert_equal "Studio Terms", pending.fetch("terms").fetch(0).fetch("title")
    assert_equal "terms_and_condition", pending.fetch("terms").fetch(0).fetch("kind")

    current = call(:get, "/workspaces/#{@root.id}/actions/current_published_for", @token)
    assert_response :success, response.body
    assert_equal @recording.recordable.id.to_s, current.fetch("terms").fetch("id")

    before = call(:get, "/workspaces/#{@root.id}/actions/accepted", @token)
    assert_response :success, response.body
    assert_equal false, before.fetch("accepted")

    accepted = call(:post, "/workspaces/#{@root.id}/actions/accept_pending", @token)
    assert_response :success, response.body
    receipt = accepted.fetch("receipts").fetch(0)
    assert_equal @recording.id.to_s, receipt.fetch("terms_recording_id")
    assert_equal @recording.recordable.id.to_s, receipt.fetch("terms_id")
    first_accepted_at = receipt.fetch("accepted_at")

    after = call(:get, "/workspaces/#{@root.id}/actions/accepted", @token)
    assert_equal true, after.fetch("accepted")
    assert_empty call(:get, "/workspaces/#{@root.id}/actions/pending_published_list", @token).fetch("terms")

    repeat = call(:post, "/workspaces/#{@root.id}/actions/accept_pending", @token)
    assert_response :success, response.body
    assert_equal 1, repeat.fetch("receipts").size
    assert_equal first_accepted_at, repeat.fetch("receipts").fetch(0).fetch("accepted_at")
    assert_equal 1, RecordingStudioTermsAndConditions::Acceptance.where(
      actor_type: receipt.fetch("actor_type"),
      actor_id: receipt.fetch("actor_id"),
      terms_recording_id: @recording.id
    ).count
  end

  test "unauthenticated calls are 401" do
    get "#{BASE}/workspaces/#{@root.id}/actions/pending_published_list", as: :json
    assert_response :unauthorized
    assert_equal "authentication_failed", json.dig("error", "code")
  end

  test "a grant that does not satisfy view is 403" do
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: @root,
      manager_actor: @owner,
      role: :edit,
      name: "Denied #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    access = provision.value.fetch(:access_recording).recordable
    RecordingStudio::Access.where(id: access.id).update_all(depends_on_recording_id: SecureRandom.uuid)

    call(:get, "/workspaces/#{@root.id}/actions/pending_published_list", issued.value.fetch(:access_token))
    assert_response :forbidden, response.body
    assert_equal "forbidden", json.dig("error", "code")
  end

  test "foreign workspace is 404" do
    outsider = user("foreign")
    Current.actor = outsider
    other = Workspace.create!(name: "Foreign #{SecureRandom.hex(4)}")
    other_root = RecordingStudio.root_recording_for(other)
    other_access = bootstrap!(other_root, outsider)
    outsider_token = token_for(other_access, manager: outsider)

    call(:post, "/workspaces/#{@root.id}/actions/accept_pending", outsider_token)
    assert_response :not_found, response.body
    assert_equal "not_found", json.dig("error", "code")
  end

  test "accept pending with no live terms returns empty receipts" do
    empty_workspace = Workspace.create!(name: "Empty #{SecureRandom.hex(4)}")
    empty_root = RecordingStudio.root_recording_for(empty_workspace)
    empty_access = bootstrap!(empty_root, @owner)
    token = token_for(empty_access)

    result = call(:post, "/workspaces/#{empty_root.id}/actions/accept_pending", token)
    assert_response :success, response.body
    assert_equal [], result.fetch("receipts")
    assert_empty call(:get, "/workspaces/#{empty_root.id}/actions/pending_published_list", token).fetch("terms")
    current = call(:get, "/workspaces/#{empty_root.id}/actions/current_published_for", token)
    assert_nil current.fetch("terms")
    assert_equal false, call(:get, "/workspaces/#{empty_root.id}/actions/accepted", token).fetch("accepted")
  end

  test "actions register on public and operations with view" do
    %i[public operations].each do |api|
      action = RecordingStudioApi.capability_action(:accept_pending, api: api)
      assert_equal :terms_and_conditions, action.capability
      assert_equal :member, action.scope
      assert_equal :view, action.required_role
      assert_equal "Terms - Accept", action.openapi.fetch(:title)
      assert RecordingStudioApi.capability_action(:pending_published_list, api: api)
      assert RecordingStudioApi.capability_action(:current_published_for, api: api)
      assert RecordingStudioApi.capability_action(:accepted, api: api)
    end
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  def bootstrap!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    raise result.error if result.respond_to?(:failure?) && result.failure?

    result.respond_to?(:value) ? result.value : result
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

    issued.value.fetch(:access_token)
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
