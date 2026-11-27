# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

User.before_create { skip_confirmation! if respond_to?(:skip_confirmation!) }

module TermsDemoTestHelper
  def bootstrap_owner_access!(actor, recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return result.value if result.respond_to?(:success?) && result.success?

    if already_bootstrapped?(result)
      manager = User.find_by(email: "admin@admin.com")
      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: :admin,
        manager_actor: manager
      )
    end

    raise result.error if result.respond_to?(:failure?) && result.failure?

    result.respond_to?(:value) ? result.value : result
  end

  def already_bootstrapped?(result)
    result.error.to_s.include?("Access already exists")
  end

  def recording_write_actor
    actor = Current.actor || User.find_by(email: "admin@admin.com") || User.create!(
      email: "writer-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = actor if defined?(Current) && Current.respond_to?(:actor=)
    actor
  end

  def grant_write_access!(recording, actor = nil)
    writer = actor || recording_write_actor
    return writer if recording.blank?

    root = recording.respond_to?(:root_recording) ? (recording.root_recording || recording) : recording
    return library_writer(writer) if root&.recordable_type == "RecordingStudioTermsAndConditions::Library"
    return writer if RecordingStudioAccessible.authorized?(actor: writer, recording: root, role: :edit)

    admin = held_access_admin
    ensure_held_admin_on!(root, admin)
    return writer if writer == admin || RecordingStudioAccessible.authorized?(actor: writer, recording: root, role: :edit)

    grant_through_admin!(root, writer, admin)
    writer
  end

  def held_access_admin
    User.find_by(email: "admin@admin.com") || User.create!(
      email: "admin@admin.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  def ensure_held_admin_on!(root, admin)
    return if RecordingStudioAccessible.authorized?(actor: admin, recording: root, role: :admin)

    existing = access_admin_for(root)
    if existing
      grant_through_admin!(root, admin, existing) unless existing == admin
      return
    end

    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: admin)
    return if result.respond_to?(:success?) && result.success?
    if already_bootstrapped?(result)
      manager = access_admin_for(root)
      raise result.error unless manager

      grant_through_admin!(root, admin, manager) unless manager == admin
      return
    end

    raise result.error if result.respond_to?(:failure?) && result.failure?
  end

  def grant_through_admin!(root, actor, admin)
    previous_actor = Current.actor if defined?(Current)
    begin
      Current.actor = admin if defined?(Current) && Current.respond_to?(:actor=)
      result = RecordingStudioAccessible.grant_access(
        recording: root,
        actor: actor,
        role: :admin,
        manager_actor: admin
      )
      raise result.error if result.respond_to?(:failure?) && result.failure?
    ensure
      Current.actor = previous_actor if defined?(Current) && Current.respond_to?(:actor=)
    end
  end

  def access_admin_for(recording)
    return unless RecordingStudioAccessible.respond_to?(:access_recordings_for)

    RecordingStudioAccessible.access_recordings_for(recording).each do |access_recording|
      access = access_recording.recordable
      next unless access.respond_to?(:role) && access.role.to_s == "admin"
      next unless access.respond_to?(:actor) && access.actor

      return access.actor
    end
    nil
  end

  def grant_workspace_access!(actor, workspace)
    recording = RecordingStudio.create_root_recording!(workspace, actor: actor)
    return recording if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

    bootstrap_owner_access!(actor, recording)
  end

  def library_writer(actor = nil)
    writer = actor || recording_write_actor
    admin = seeded_admin_recording
    return writer if admin && RecordingStudioAccessible.authorized?(actor: writer, recording: admin, role: :edit)

    staff = held_access_admin
    ensure_held_admin_on!(admin, staff) if admin
    Current.actor = staff if defined?(Current) && Current.respond_to?(:actor=)
    staff
  end

  def seeded_admin_recording
    return RecordingStudioAccessible.admin_root if RecordingStudioAccessible.respond_to?(:admin_root) &&
                                                   RecordingStudioAccessible.admin_root

    admin = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin) ||
      RecordingStudio.create_root_recording!(admin, actor: held_access_admin)
  end

  def terms_library(actor = nil)
    writer = library_writer(actor)
    RecordingStudioTermsAndConditions.library_root(actor: writer)
  end

  def record_terms(_root_recording = nil, title:, body:, kind: RecordingStudioTermsAndConditions::Terms::DEFAULT_KIND, actor: nil)
    writer = library_writer(actor)
    terms_library(writer).record(RecordingStudioTermsAndConditions::Terms, actor: writer) do |terms|
      terms.title = title
      terms.body = body
      terms.kind = kind
    end
  end

  def unpublish_live_terms!
    library = RecordingStudioTermsAndConditions.library_root
    return if library.blank?

    RecordingStudio::Recording.where(
      root_recording_id: library.id,
      recordable_type: RecordingStudioTermsAndConditions::Terms.name,
      trashed_at: nil
    ).find_each do |recording|
      next unless recording.respond_to?(:currently_published?) && recording.currently_published?

      draft_published_recording!(recording)
    end
  end

  def draft_published_recording!(recording)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "draft-#{recording.id.to_s.first(8)}", status: "draft" },
      actor: library_writer
    ).value!
  end

  def publish_terms!(recording, slug:, status: "published", actor: nil)
    writer = library_writer(actor)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: status },
      actor: writer
    ).value!
  end

  def switch_to_workspace(workspace)
    recording = RecordingStudio.root_recording_for(workspace) ||
                RecordingStudio.create_root_recording!(workspace, actor: recording_write_actor)
    # Root Switchable 0.12+ forbids the switch page without Accessible :view on
    # the current root. Persist the selection on this device first so later
    # requests land on the target even when that page returns 403.
    remember_switch_selection!(@terms_signed_in_user, recording) if @terms_signed_in_user
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: recording.id,
        return_to: "/"
      }
    }
  end

  def remember_switch_selection!(actor, recording)
    return unless actor && recording
    return unless defined?(RecordingStudio::RootSwitchable::Selection)

    RecordingStudio::RootSwitchable::Selection.upsert_for(
      actor: actor,
      device_key: switch_device_key,
      scope_key: "all_workspaces",
      root_recording: recording
    )
  end

  def switch_device_key
    return @switch_device_key if @switch_device_key.present?

    name = RecordingStudioRootSwitchable.configuration.device_key_cookie_name
    key = SecureRandom.uuid
    request = ActionDispatch::TestRequest.create(Rails.application.env_config)
    options = RecordingStudioRootSwitchable.configuration.resolved_device_key_cookie_options
    request.cookie_jar.encrypted[name] = options.merge(value: key)
    cookies[name.to_s] = request.cookie_jar[name]
    @switch_device_key = key
  end

  def grant_view_access!(actor, recordable)
    return unless actor && recordable

    recording = recordable if recordable.is_a?(RecordingStudio::Recording)
    recording ||= RecordingStudio.create_root_recording!(recordable, actor: actor)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

    manager = access_admin_for(recording)
    if manager && manager != actor
      previous_actor = Current.actor if defined?(Current)
      begin
        Current.actor = manager if defined?(Current) && Current.respond_to?(:actor=)
        result = RecordingStudioAccessible.grant_access(
          recording: recording,
          actor: actor,
          role: :view,
          manager_actor: manager
        )
        raise result.error if result.respond_to?(:failure?) && result.failure?
      ensure
        Current.actor = previous_actor if defined?(Current) && Current.respond_to?(:actor=)
      end
      return
    end

    bootstrap_owner_access!(actor, recording)
  end

  def grant_current_root_view!(actor)
    return unless actor

    RecordingStudio::RootSwitchable::Selection.where(actor: actor).find_each do |selection|
      recordable = selection.root_recording&.recordable
      grant_view_access!(actor, recordable) if recordable
    end

    current = dummy_default_switch_root
    grant_view_access!(actor, current.recordable) if current&.recordable
  end

  def dummy_default_switch_root
    admin = AdminRoot.find_by(name: "Admin")
    admin_recording = admin && RecordingStudio.root_recording_for(admin)
    workspace_roots = Workspace.order(:name).filter_map do |workspace|
      RecordingStudio.root_recording_for(workspace)
    end
    roots = [ admin_recording, *workspace_roots ].compact
    roots.find { |root| root.recordable.try(:name) == "Studio Workspace" } || roots.first
  end

  def without_live_terms_fallback
    yield
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

  def token_for(access_point, role:, api:, manager: nil)
    manager ||= @owner
    configuration = RecordingStudioAccessible.configuration
    original = configuration.access_management_authorizer
    configuration.access_management_authorizer = ->(**) { true }
    provision = with_access_creation do
      RecordingStudioApi::Services::ProvisionApiClient.call(
        access_point_recording: access_point,
        manager_actor: manager,
        role: role,
        name: "Client #{SecureRandom.hex(3)}",
        api: api
      )
    end
    raise provision.error unless provision.success?

    client = provision.value.fetch(:api_client)
    grant!(access_point, client, role, manager)

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

  def public_token_for(access_recording, manager: @owner)
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

  def with_access_creation(&)
    if defined?(RecordingStudioAccessible::AccessCreationContext)
      RecordingStudioAccessible::AccessCreationContext.allow(&)
    else
      yield
    end
  end

  def call(method, path, token, params = {})
    send(method, path, params: params, headers: headers(token), as: :json)
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

  def assert_forbidden_not_allowed
    assert_response :forbidden, response.body
    assert_equal "forbidden", json.dig("error", "code")
    message = json.dig("error", "message").to_s.downcase
    assert message.include?("not authorized") || message.include?("not allowed") || message.include?("admin access"),
           message
  end

  def free_kind!
    kind = RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    RecordingStudioTermsAndConditions::KindPresence.recordings_for(kind: kind).each do |recording|
      recording.update_columns(trashed_at: Time.current)
    end
    kind
  end
end

module TermsSignInTracker
  def sign_in(resource, *args, **kwargs)
    @terms_signed_in_user = resource if resource.is_a?(User)
    super
  end
end

class ActionDispatch::IntegrationTest
  def self.inherited(subclass)
    super
    subclass.prepend(TermsSignInTracker)
  end
end

class ActiveSupport::TestCase
  include TermsDemoTestHelper

  # db:prepare loads seeds. Those live documents sit on the shared library, so
  # they would gate every actor. Draft them for the example, then restore the actor.
  setup do
    previous_actor = defined?(Current) ? Current.actor : nil
    unpublish_live_terms!
  ensure
    Current.actor = previous_actor if defined?(Current) && Current.respond_to?(:actor=)
  end
end
