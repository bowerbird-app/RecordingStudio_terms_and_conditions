# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"

class PrivacyPolicyWaveTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "privacy-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @admin = User.create!(
      email: "privacy-admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Privacy #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    unless RecordingStudioAccessible.authorized?(actor: @admin, recording: @admin_recording, role: :edit)
      bootstrap_owner_access!(@admin, @admin_recording)
    end
  end

  test "kind constraints and create uniqueness per kind" do
    terms = record_terms(@root, title: "Studio Terms", body: "Be kind.")
    assert_equal "terms_and_condition", terms.recordable.kind

    privacy = record_terms(
      @root,
      title: "Studio Privacy",
      body: "We keep receipts.",
      kind: RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    )
    assert_equal "privacy_policy", privacy.recordable.kind
    assert_equal "Privacy Policy", privacy.recordable.kind_label

    assert RecordingStudioTermsAndConditions::KindPresence.exists?(@root, kind: "terms_and_condition")
    assert RecordingStudioTermsAndConditions::KindPresence.exists?(@root, kind: "privacy_policy")
    assert_empty RecordingStudioTermsAndConditions::KindPresence.available_kinds(@root)

    sign_in @admin
    switch_to_workspace(@admin_root)

    post recording_studio_terms_and_conditions.admin_terms_path, params: {
      terms: {
        title: "Admin Privacy",
        body: "House privacy.",
        kind: "privacy_policy"
      }
    }
    assert_includes [302, 422], response.status

    assert_no_difference -> {
      RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count
    } do
      post recording_studio_terms_and_conditions.admin_terms_path, params: {
        terms: {
          title: "Extra Privacy",
          body: "Nope.",
          kind: "privacy_policy"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "already has Privacy Policy"
  end

  test "trashed recordings do not block a new document of that kind" do
    privacy = record_terms(
      @root,
      title: "Old Privacy",
      body: "Gone.",
      kind: RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    )
    privacy.update_columns(trashed_at: Time.current)

    refute RecordingStudioTermsAndConditions::KindPresence.exists?(@root, kind: "privacy_policy")
    assert_includes RecordingStudioTermsAndConditions::KindPresence.available_kinds(@root), "privacy_policy"
  end

  test "SoleLive is per kind" do
    terms_v1 = record_terms(@root, title: "Terms v1", body: "One.")
    publish_terms!(terms_v1, slug: "terms-v1-#{SecureRandom.hex(4)}")
    privacy_v1 = record_terms(
      @root,
      title: "Privacy v1",
      body: "Private one.",
      kind: RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    )
    publish_terms!(privacy_v1, slug: "privacy-v1-#{SecureRandom.hex(4)}")

    terms_v2 = @root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = "Terms v2"
      terms.body = "Two."
      terms.kind = "terms_and_condition"
    end
    publish_terms!(terms_v2, slug: "terms-v2-#{SecureRandom.hex(4)}")

    terms_v1.reload
    privacy_v1.reload
    terms_v2.reload
    refute terms_v1.currently_published?
    assert terms_v2.currently_published?
    assert privacy_v1.currently_published?
  end

  test "gate pending covers zero to two live kinds and multi-accept writes two rows" do
    terms = record_terms(@root, title: "Studio Terms", body: "Be kind.")
    publish_terms!(terms, slug: "both-terms-#{SecureRandom.hex(4)}")
    privacy = record_terms(
      @root,
      title: "Studio Privacy",
      body: "We keep receipts.",
      kind: RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    )
    publish_terms!(privacy, slug: "both-privacy-#{SecureRandom.hex(4)}")

    pending = RecordingStudioTermsAndConditions.pending_published_list(@user, @workspace)
    assert_equal 2, pending.size
    assert_equal %w[terms_and_condition privacy_policy], pending.map(&:kind)

    sign_in @user
    switch_to_workspace(@workspace)

    get recording_studio_terms_and_conditions.acceptance_path
    assert_response :success
    assert_includes response.body, "Studio Terms"
    assert_includes response.body, "Studio Privacy"
    assert_match(/and privacy policy/, CGI.unescapeHTML(response.body).gsub(/<[^>]+>/, ""))
    assert_select "[data-controller='flat-pack--collapse']", count: 2

    assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, 2 do
      post recording_studio_terms_and_conditions.acceptance_path
    end
    assert_redirected_to "/"
    assert_empty RecordingStudioTermsAndConditions.pending_published_list(@user, @workspace)
    assert RecordingStudioTermsAndConditions.accepted?(@user, @workspace, kind: "terms_and_condition")
    assert RecordingStudioTermsAndConditions.accepted?(@user, @workspace, kind: "privacy_policy")

    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      RecordingStudioTermsAndConditions.accept!(@user, terms.recordable, { "source" => "continue_notice" })
      RecordingStudioTermsAndConditions.accept!(@user, privacy.recordable, { "source" => "continue_notice" })
      post recording_studio_terms_and_conditions.acceptance_path
    end
  end

  test "public privacy route and published_url use /privacy" do
    privacy = record_terms(
      @root,
      title: "Studio Privacy",
      body: "We keep receipts.",
      kind: RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    )
    publish_terms!(privacy, slug: "studio-privacy-#{SecureRandom.hex(4)}")
    publishable = privacy.publishable_child_recording
    slug = publishable.recordable.slug

    get "/privacy/#{publishable.id}/#{slug}"
    assert_response :success
    assert_includes response.body, "Studio Privacy"
    assert_includes response.body, "We keep receipts"
    assert_includes privacy.recordable.published_url, "/privacy/"
    refute_includes privacy.recordable.published_url, "/terms/"
  end

  test "continue notice and agree checkbox mention privacy with modal and new tab" do
    terms = record_terms(@root, title: "Studio Terms", body: "Be kind.")
    publish_terms!(terms, slug: "helper-terms-#{SecureRandom.hex(4)}")
    privacy = record_terms(
      @root,
      title: "Studio Privacy",
      body: "We keep receipts.",
      kind: RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY
    )
    publish_terms!(privacy, slug: "helper-privacy-#{SecureRandom.hex(4)}")

    sign_in @user
    switch_to_workspace(@workspace)

    get "/agree_helper"
    assert_response :success
    assert_includes CGI.unescapeHTML(response.body), "privacy policy"
    assert_match(/and <a[^>]*>privacy policy<\/a>/, response.body)
    assert_includes response.body, "I agree to these"
    assert_select "a.flat-pack-link[href*='/terms/']", text: "terms"
    assert_select "a.flat-pack-link[href*='/privacy/'][target=_blank]", text: "privacy policy"
    assert_select "a.flat-pack-link[data-modal-id]", text: "Terms & Conditions"
    assert_select "a.flat-pack-link[data-modal-id]", text: "privacy policy"
    assert_select "[data-controller='flat-pack--modal']", count: 2
  end
end
