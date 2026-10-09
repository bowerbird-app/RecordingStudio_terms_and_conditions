# frozen_string_literal: true

require "test_helper"

class TermsMetricsApiTest < ActionDispatch::IntegrationTest
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"
  PUBLIC_ROOT = "/recording_studio_api/api/v1"

  setup do
    @staff = User.create!(
      email: "metrics-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @patron = User.create!(
      email: "metrics-patron-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @staff
    @workspace = Workspace.create!(name: "Metrics #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    grant!(@admin_root, @staff, :admin)
    bootstrap_owner!(@root, @staff)
    grant!(@root, @patron, :edit)

    seed_acceptances!

    @staff_operations_token = provision_token(
      access_point: @admin_root,
      actor: @staff,
      role: :edit,
      name: "Staff operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @workspace_operations_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :edit,
      name: "Workspace operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @public_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :view,
      name: "Public metrics #{SecureRandom.hex(4)}"
    )
    Current.actor = nil
  end

  teardown do
    Current.actor = nil
  end

  test "operations staff token reads terms acceptance metrics" do
    get "#{OPERATIONS_ROOT}/metrics/terms_acceptances/total",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal RecordingStudioTermsAndConditions::Acceptance.count, response.parsed_body.fetch("value")
    assert_operator response.parsed_body.fetch("value"), :>=, 4

    get "#{OPERATIONS_ROOT}/metrics/terms_acceptances/by_version",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    version_counts = breakdown_counts(response.parsed_body)
    assert_equal RecordingStudioTermsAndConditions::Acceptance.where(terms_recording_id: @v1.id).count,
                 version_counts[@v1.id.to_s]
    assert_equal RecordingStudioTermsAndConditions::Acceptance.where(terms_recording_id: @v2.id).count,
                 version_counts[@v2.id.to_s]
    refute_includes version_counts.keys, @v1.recordable.id.to_s
    refute_includes version_counts.keys, @v2.recordable.id.to_s

    get "#{OPERATIONS_ROOT}/metrics/terms_acceptances/over_time",
        params: { interval: "day" },
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    over_time = timeseries_counts(response.parsed_body)
    assert_equal acceptances_on(@day_one), over_time[@day_one.strftime("%Y-%m-%d")]
    assert_equal acceptances_on(@day_two), over_time[@day_two.strftime("%Y-%m-%d")]
    assert_equal acceptances_on(@day_three), over_time[@day_three.strftime("%Y-%m-%d")]
    assert_operator over_time[@day_one.strftime("%Y-%m-%d")], :>=, 1
    assert_operator over_time[@day_two.strftime("%Y-%m-%d")], :>=, 1
    assert_operator over_time[@day_three.strftime("%Y-%m-%d")], :>=, 2
  end

  test "by_version includes a trashed terms recording without raising" do
    extra = User.create!(
      email: "metrics-trashed-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    trashed = record_terms(@root, title: "Terms v1", body: "Trashed copy.")
    publish_terms!(trashed, slug: "terms-trashed-#{SecureRandom.hex(4)}")
    accept!(extra, trashed, at: 2.days.ago)
    trashed.update_columns(trashed_at: Time.current)

    get "#{OPERATIONS_ROOT}/metrics/terms_acceptances/by_version",
        headers: auth(@staff_operations_token),
        as: :json

    assert_response :success
    version_counts = breakdown_counts(response.parsed_body)
    assert_equal 1, version_counts[trashed.id.to_s]
    assert_equal RecordingStudioTermsAndConditions::Acceptance.where(terms_recording_id: @v1.id).count,
                 version_counts[@v1.id.to_s]
    refute_equal trashed.id.to_s, @v1.id.to_s
  end

  test "metrics index lists terms acceptance metrics" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json

    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    %w[
      terms_acceptances.total
      terms_acceptances.over_time
      terms_acceptances.by_version
    ].each { |identifier| assert_includes identifiers, identifier }
  end

  test "non-admin operations token is denied terms metrics" do
    get "#{OPERATIONS_ROOT}/metrics/terms_acceptances/total",
        headers: auth(@workspace_operations_token),
        as: :json
    assert_response :forbidden

    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@workspace_operations_token), as: :json
    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    refute_includes identifiers, "terms_acceptances.total"
  end

  test "public API token is denied operations terms metrics" do
    get "#{OPERATIONS_ROOT}/metrics/terms_acceptances/total",
        headers: auth(@public_token),
        as: :json
    assert_response :unauthorized

    get "#{PUBLIC_ROOT}/metrics/terms_acceptances/total",
        headers: auth(@public_token),
        as: :json
    assert_includes [ 404, 401, 403 ], response.status
  end

  private

  def seed_acceptances!
    extra = User.create!(
      email: "metrics-extra-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )

    @day_one = 5.days.ago.beginning_of_day
    @day_two = 4.days.ago.beginning_of_day
    @day_three = 3.days.ago.beginning_of_day

    @v1 = record_terms(@root, title: "Terms v1", body: "First copy.")
    publish_terms!(@v1, slug: "terms-v1-#{SecureRandom.hex(4)}")
    accept!(@patron, @v1, at: @day_one + 12.hours)
    accept!(@staff, @v1, at: @day_two + 12.hours)

    @v2 = record_terms(@root, title: "Terms v2", body: "Second copy.")
    publish_terms!(@v2, slug: "terms-v2-#{SecureRandom.hex(4)}")
    accept!(@patron, @v2, at: @day_three + 9.hours)
    accept!(extra, @v2, at: @day_three + 15.hours)
  end

  def accept!(actor, recording, at:)
    terms = recording.recordable
    travel_to at do
      RecordingStudioTermsAndConditions::Acceptance.create!(
        actor: actor,
        terms_recording_id: recording.id,
        terms_id: terms.id,
        accepted_at: Time.current,
        body_digest: RecordingStudioTermsAndConditions::BodyDigest.call(terms.body),
        provenance: { "source" => "metrics_test" }
      )
    end
  end

  def acceptances_on(day)
    RecordingStudioTermsAndConditions::Acceptance.where(accepted_at: day...(day + 1.day)).count
  end

  def breakdown_counts(payload)
    payload.fetch("data").to_h { |row| [ row.fetch("key").to_s, row.fetch("value") ] }
  end

  def timeseries_counts(payload)
    payload.fetch("data").to_h { |row| [ row.fetch("date").to_s, row.fetch("value") ] }
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(access_point:, actor:, role:, name:, api: :public)
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: actor,
      role: role,
      name: name,
      api: api
    )
    raise result.error unless result.success?

    payload = result.value
    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.fetch(:credential).oauth_client_id,
      client_secret: payload.fetch(:token),
      api: api
    )
    raise token_result.error unless token_result.success?

    token_result.value.fetch(:access_token)
  end

  def bootstrap_owner!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: recording,
      actor: actor
    )
    raise result.error if result.failure?
  end

  def grant!(recording, actor, role)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)

    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
