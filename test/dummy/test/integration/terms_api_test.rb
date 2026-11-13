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

  test "grant actor can read pending current and accepted" do
    pending = call(:get, "/workspaces/#{@root.id}/actions/terms_pending_published_list", @token)
    assert_response :success, response.body
    assert_equal "Studio Terms", pending.fetch("terms").fetch(0).fetch("title")
    assert_equal "terms_and_condition", pending.fetch("terms").fetch(0).fetch("kind")

    current = call(:get, "/workspaces/#{@root.id}/actions/terms_current_published_for", @token)
    assert_response :success, response.body
    assert_equal @recording.recordable.id.to_s, current.fetch("terms").fetch("id")

    before = call(:get, "/workspaces/#{@root.id}/actions/terms_accepted", @token)
    assert_response :success, response.body
    assert_equal false, before.fetch("accepted")
  end

  test "unauthenticated calls are 401" do
    get "#{BASE}/workspaces/#{@root.id}/actions/terms_pending_published_list", as: :json
    assert_response :unauthorized
    assert_equal "authentication_failed", json.dig("error", "code")
  end

  test "trashing the manager Access the client depends on is 403" do
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

    attached = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: provision.value.fetch(:api_client),
      role: :edit,
      manager_actor: @owner,
      depends_on: @owner_access
    )
    raise attached.error if attached.respond_to?(:failure?) && attached.failure?

    @owner_access.log_event!(action: "trashed", actor: @owner)
    @owner_access.update!(trashed_at: Time.current)

    call(:get, "/workspaces/#{@root.id}/actions/terms_pending_published_list", issued.value.fetch(:access_token))
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

    call(:get, "/workspaces/#{@root.id}/actions/terms_pending_published_list", outsider_token)
    assert_response :not_found, response.body
    assert_equal "not_found", json.dig("error", "code")
  end

  test "reads with no live terms return empty pending nil current and unaccepted" do
    empty_workspace = Workspace.create!(name: "Empty #{SecureRandom.hex(4)}")
    empty_root = RecordingStudio.root_recording_for(empty_workspace)
    empty_access = bootstrap!(empty_root, @owner)
    token = token_for(empty_access)

    assert_empty call(:get, "/workspaces/#{empty_root.id}/actions/terms_pending_published_list", token).fetch("terms")
    current = call(:get, "/workspaces/#{empty_root.id}/actions/terms_current_published_for", token)
    assert_nil current.fetch("terms")
    assert_equal false, call(:get, "/workspaces/#{empty_root.id}/actions/terms_accepted", token).fetch("accepted")
  end

  test "registry does not list terms_accept_pending" do
    %i[public operations].each do |api|
      refute RecordingStudioApi.capability_action(:terms_accept_pending, api: api)
    end
    refute_includes RecordingStudioTermsAndConditions::Api::ACTIONS.keys, :terms_accept_pending
    names = RecordingStudioTermsAndConditions::Api::ACTIONS.keys +
            RecordingStudioTermsAndConditions::Api::AdminActions.definitions.keys
    refute_includes names, :terms_accept
    refute_includes names, :accept_terms
    api_dir = RecordingStudioTermsAndConditions::Engine.root.join("lib/recording_studio_terms_and_conditions/api")
    Dir.glob(api_dir.join("*.rb")).each do |path|
      refute_includes File.read(path), "accept!", "#{path} must not accept Terms"
    end
  end

  test "actions register on public and operations with view and collide on a second register" do
    %i[public operations].each do |api|
      action = RecordingStudioApi.capability_action(:terms_pending_published_list, api: api)
      assert_equal :terms_and_conditions, action.capability
      assert_equal :member, action.scope
      assert_equal :view, action.required_role
      assert RecordingStudioApi.capability_action(:terms_pending_published_list, api: api)
      assert RecordingStudioApi.capability_action(:terms_current_published_for, api: api)
      assert RecordingStudioApi.capability_action(:terms_accepted, api: api)
    end

    error = assert_raises(ArgumentError) { RecordingStudioTermsAndConditions::Api.register_capability_action! }
    assert_match(/already registered/, error.message)
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
