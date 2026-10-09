# frozen_string_literal: true

require "test_helper"

class TermsMetricsTest < ActiveSupport::TestCase
  include TermsDemoTestHelper

  GrantContext = Struct.new(:access_grant)
  Grant = Struct.new(:actor)

  setup do
    @staff = User.create!(
      email: "metrics-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @outsider = User.create!(
      email: "metrics-outsider-#{SecureRandom.hex(4)}@example.com",
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
    Current.actor = nil
  end

  teardown do
    Current.actor = nil
  end

  test "registered terms metrics return seeded acceptance values" do
    identifiers = RecordingStudioMetrics.definitions.map(&:identifier)
    %w[
      terms_acceptances.total
      terms_acceptances.over_time
      terms_acceptances.by_version
    ].each { |identifier| assert_includes identifiers, identifier }

    assert_equal RecordingStudioTermsAndConditions::Acceptance.count, execute("terms_acceptances.total").value
    assert_operator execute("terms_acceptances.total").value, :>=, 4

    version_counts = breakdown_counts(execute("terms_acceptances.by_version"))
    assert_equal RecordingStudioTermsAndConditions::Acceptance.where(terms_recording_id: @v1.id).count,
                 version_counts[@v1.id.to_s].to_i
    assert_equal RecordingStudioTermsAndConditions::Acceptance.where(terms_recording_id: @v2.id).count,
                 version_counts[@v2.id.to_s].to_i
    refute_includes version_counts.keys, @v1.recordable.id.to_s
    refute_includes version_counts.keys, @v2.recordable.id.to_s

    opened = timeseries_counts(
      execute(
        "terms_acceptances.over_time",
        interval: "day",
        start_at: Time.utc(2026, 10, 4),
        end_at: Time.utc(2026, 10, 8)
      )
    )
    assert_equal acceptances_on(Time.utc(2026, 10, 5)), opened["2026-10-05"]
    assert_equal acceptances_on(Time.utc(2026, 10, 6)), opened["2026-10-06"]
    assert_equal acceptances_on(Time.utc(2026, 10, 7)), opened["2026-10-07"]
    assert_operator opened["2026-10-05"], :>=, 1
    assert_operator opened["2026-10-06"], :>=, 1
    assert_operator opened["2026-10-07"], :>=, 2
  end

  test "by_version includes a trashed terms recording without raising" do
    extra = User.create!(
      email: "metrics-trashed-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @staff
    trashed = record_terms(@root, title: "Terms v1", body: "Trashed copy.")
    publish_terms!(trashed, slug: "terms-trashed-#{SecureRandom.hex(4)}")
    accept!(extra, trashed, at: Time.utc(2026, 10, 6, 15))
    trashed.update_columns(trashed_at: Time.current)
    Current.actor = nil

    version_counts = breakdown_counts(execute("terms_acceptances.by_version"))
    assert_equal 1, version_counts[trashed.id.to_s].to_i
    assert_equal RecordingStudioTermsAndConditions::Acceptance.where(terms_recording_id: @v1.id).count,
                 version_counts[@v1.id.to_s].to_i
    refute_equal trashed.id.to_s, @v1.id.to_s
  end

  test "api_authorize allows AdminRoot staff and denies non-admins" do
    authorize = RecordingStudioMetrics.registry.api_authorize_for(:terms_acceptances)
    assert_equal RecordingStudioTermsAndConditions::Metrics::AUTHORIZE, authorize

    assert authorize.call(GrantContext.new(Grant.new(@staff)))
    refute authorize.call(GrantContext.new(Grant.new(@outsider)))
    refute authorize.call(GrantContext.new(Grant.new(nil)))
  end

  private

  def execute(identifier, **params)
    RecordingStudioMetrics.execute(
      identifier,
      context: site_context,
      cache: false,
      **params
    )
  end

  def site_context
    RecordingStudioMetrics::Context.new(
      scope: :site,
      actor: @staff,
      site_authorized: true,
      timezone: "UTC"
    )
  end

  def seed_acceptances!
    extra = User.create!(
      email: "metrics-extra-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )

    @v1 = record_terms(@root, title: "Terms v1", body: "First copy.")
    publish_terms!(@v1, slug: "terms-v1-#{SecureRandom.hex(4)}")
    accept!(@patron, @v1, at: Time.utc(2026, 10, 5, 12))
    accept!(@staff, @v1, at: Time.utc(2026, 10, 6, 12))

    @v2 = record_terms(@root, title: "Terms v2", body: "Second copy.")
    publish_terms!(@v2, slug: "terms-v2-#{SecureRandom.hex(4)}")
    accept!(@patron, @v2, at: Time.utc(2026, 10, 7, 9))
    accept!(extra, @v2, at: Time.utc(2026, 10, 7, 15))
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

  def breakdown_counts(result)
    result.data.to_h { |row| [ (row[:key] || row["key"]).to_s, row[:value] || row["value"] ] }
  end

  def timeseries_counts(result)
    result.data.to_h { |row| [ (row[:date] || row["date"]).to_s, row[:value] || row["value"] ] }
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
