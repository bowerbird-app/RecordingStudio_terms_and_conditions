# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminTermsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Admin write #{SecureRandom.hex(4)}")
    RecordingStudio.root_recording_for(@workspace)
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    unless RecordingStudioAccessible.authorized?(actor: @admin, recording: @admin_recording, role: :edit)
      bootstrap_owner_access!(@admin, @admin_recording)
    end
  end

  test "admin without access is forbidden" do
    sign_in @member

    get recording_studio_terms_and_conditions.admin_terms_path

    assert_response :forbidden
  end

  test "member cannot open Users receipts" do
    sign_in @admin
    switch_to_workspace(@workspace)
    recording = RecordingStudio.root_recording_for(@workspace).record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Quiet hours"
      terms.body = "Headphones after ten."
    end

    sign_in @member
    get recording_studio_terms_and_conditions.admin_term_users_path(recording)

    assert_response :forbidden
  end

  test "admin can draft and revise terms" do
    sign_in @admin
    switch_to_workspace(@workspace)

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_includes response.body, "New"
    assert(
      response.body.include?("No terms yet") || response.body.include?("Title"),
      "expected an empty state or the Terms table"
    )
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    refute_select "header.fp-top-nav"
    refute_includes response.body, "Terms demo"
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_match %r{flat_pack/application}, response.body

    get recording_studio_terms_and_conditions.new_admin_term_path
    assert_response :success
    assert_includes response.body, "New Terms and Conditions"
    assert_includes response.body, "flat-pack--tiptap"
    assert_includes response.body, "terms[body]"
    refute_includes response.body, "terms[change_note]"
    refute_includes response.body, "What changed"
    refute_includes response.body, "terms[category]"
    refute_includes response.body, "Category"
    assert_includes response.body, "Save draft"
    assert_select "div.inline-block button[type=submit]", text: "Save draft"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "nav[aria-label='Page navigation']", count: 1
    refute_select "header.fp-top-nav"
    refute_includes response.body, "Terms demo"
    refute_includes response.body, "Write terms"

    assert_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count }, 1 do
      post recording_studio_terms_and_conditions.admin_terms_path, params: {
        terms: { title: "House rules", body: "No yelling in the booth." }
      }
    end

    recording = RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name)
                                          .order(:created_at).last
    assert_redirected_to recording_studio_terms_and_conditions.admin_term_path(recording)
    follow_redirect!
    assert_includes response.body, "Terms drafted. Publish when they are ready."
    refute_select "header.fp-top-nav"
    assert_includes response.body, "House rules"
    assert_includes response.body, "Recording"
    assert_includes response.body, "flat-pack-content-editor-content"
    assert_includes response.body, "Publish"
    assert_select "a", text: "Users"
    refute_includes response.body, "Who agreed"
    refute_includes response.body, "Nobody yet"

    get recording_studio_terms_and_conditions.admin_term_users_path(recording)
    assert_response :success
    assert_includes response.body, "Users"
    assert_includes response.body, "Nobody yet"
    assert_includes response.body, "People who ticked the box for these terms."

    publish_terms!(recording, slug: "house-rules-#{SecureRandom.hex(4)}")
    RecordingStudioTermsAndConditions.accept!(@member, recording, { "source" => "clickwrap" })
    get recording_studio_terms_and_conditions.admin_term_users_path(recording)
    assert_response :success
    assert_includes response.body, @member.email
    refute_includes response.body, "Nobody yet"

    original_snapshot_id = recording.recordable_id
    assert_difference -> { RecordingStudioTermsAndConditions::Terms.count }, 1 do
      assert_no_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count } do
        patch recording_studio_terms_and_conditions.admin_term_path(recording), params: {
          terms: { title: "House rules", body: "Whisper, please." }
        }
      end
    end

    recording.reload
    refute_equal original_snapshot_id, recording.recordable_id
    assert_equal "Whisper, please.", recording.recordable.body
    follow_redirect!
    assert_includes response.body, "Terms updated."
    assert_includes response.body, "Recording #{recording.id}"
    assert_includes response.body, "snapshot #{recording.recordable_id}"

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_includes response.body, "House rules"
    assert_select "table thead th", text: "Title"
    refute_select "table thead th", text: "Category"
    refute_select "table thead th", text: "Coverage"
    assert_select "table thead th", text: "Status"
    assert_select "table thead th", text: "Published"
    assert_select "table thead th", text: "Agrees"
    assert_select "table thead th", text: "Open"
    assert_select "table tbody td a", text: "House rules"
    assert_select "table tbody td", text: (recording.currently_published? ? "Live" : "Draft")
    assert_select "table tbody td a", text: "Open"
  end

  test "admin section registers terms coverage widgets" do
    assert RecordingStudioAdmin.section_for("terms")
    assert RecordingStudioAdmin.screen_for("recording_studio_terms_acceptances")
    assert RecordingStudioAdmin.widget_for("widgets.terms.live")
    assert RecordingStudioAdmin.widget_for("widgets.terms.agrees")
    usages = RecordingStudioTermsAndConditions::Admin::TermsSection.widget_usages
    assert_equal %w[widgets.terms.live widgets.terms.agrees], usages.map(&:key)
    assert usages.all? { |usage| usage.view_variant == :card }
    screen_usages = RecordingStudioTermsAndConditions::Admin::TermsScreen.widget_usages
    assert_equal %w[widgets.terms.live widgets.terms.agrees], screen_usages.map(&:key)
    assert screen_usages.all? { |usage| usage.view_variant == :card }
    agree_usages = RecordingStudioTermsAndConditions::Admin::AcceptancesScreen.widget_usages
    assert_equal %w[widgets.terms.agrees], agree_usages.map(&:key)
    assert_equal :card, agree_usages.first.view_variant
    assert RecordingStudioAdmin::WidgetRenderingHelper.ancestors.include?(
      RecordingStudioTermsAndConditions::AdminWidgetCard
    )
    keys = AdminRoot.recording_studio_admin_section_keys_for(@admin_root, @admin_recording, nil)
    assert_includes keys, "terms"
  end

  test "admin terms index paginates like other kit tables" do
    sign_in @admin
    switch_to_workspace(@workspace)
    26.times do |index|
      workspace = Workspace.create!(name: "Page #{index} #{SecureRandom.hex(3)}")
      root = RecordingStudio.root_recording_for(workspace)
      root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |terms|
        terms.title = "Page #{index} #{SecureRandom.hex(3)}"
        terms.body = "Body #{index}."
      end
    end

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_equal 25, first_table_row_count

    get recording_studio_terms_and_conditions.admin_terms_path, params: { page: 2 }
    assert_response :success
    page_two = first_table_row_count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
  end

  test "term users paginates receipts" do
    sign_in @admin
    switch_to_workspace(@workspace)
    recording = RecordingStudio.root_recording_for(@workspace).record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Crowd"
      terms.body = "Many people tick this."
    end
    publish_terms!(recording, slug: "crowd-#{SecureRandom.hex(4)}")
    26.times do |index|
      person = User.create!(
        email: "agree-#{index}-#{SecureRandom.hex(3)}@example.com",
        password: "Password",
        password_confirmation: "Password"
      )
      RecordingStudioTermsAndConditions.accept!(person, recording, { "source" => "clickwrap" })
    end

    get recording_studio_terms_and_conditions.admin_term_users_path(recording)
    assert_response :success
    assert_equal 25, first_table_row_count

    get recording_studio_terms_and_conditions.admin_term_users_path(recording), params: { page: 2 }
    assert_response :success
    page_two = first_table_row_count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
  end

  test "admin terms screen table paginates" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    26.times do |index|
      workspace = Workspace.create!(name: "Hub #{index} #{SecureRandom.hex(3)}")
      root = RecordingStudio.root_recording_for(workspace)
      root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |terms|
        terms.title = "Hub #{index} #{SecureRandom.hex(3)}"
        terms.body = "Hub body #{index}."
      end
    end

    get "/admin/screens/recording_studio_terms/table"
    assert_response :success
    assert_select "table tbody tr", count: 25

    get "/admin/screens/recording_studio_terms/table", params: { page: 2 }
    assert_response :success
    page_two = css_select("table tbody tr").count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
  end

  test "admin who agreed screen table paginates" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    recording = RecordingStudio.root_recording_for(@workspace).record(
      RecordingStudioTermsAndConditions::Terms,
      actor: @admin
    ) do |terms|
      terms.title = "Crowd hub"
      terms.body = "Many people tick this."
    end
    publish_terms!(recording, slug: "crowd-hub-#{SecureRandom.hex(4)}")
    26.times do |index|
      person = User.create!(
        email: "hub-agree-#{index}-#{SecureRandom.hex(3)}@example.com",
        password: "Password",
        password_confirmation: "Password"
      )
      RecordingStudioTermsAndConditions.accept!(person, recording, { "source" => "clickwrap" })
    end

    get "/admin/screens/recording_studio_terms_acceptances/table"
    assert_response :success
    assert_select "table tbody tr", count: 25

    get "/admin/screens/recording_studio_terms_acceptances/table", params: { page: 2 }
    assert_response :success
    page_two = css_select("table tbody tr").count
    assert_operator page_two, :>, 0
    assert_operator page_two, :<=, 25
  end

  test "recording studio admin terms hub is reachable and write parks there" do
    sign_in @admin
    switch_to_workspace(@admin_root)

    get "/admin"
    assert_response :success
    refute_select "header.fp-top-nav"
    assert_includes response.body, "Terms and Conditions"
    assert_includes response.body, "Old versions"
    assert_includes response.body, "Agree stats"
    write_path = RecordingStudioTermsAndConditions.admin_write_path
    assert_includes response.body, write_path
    assert_select "a[href=?]", write_path, text: "New"
    assert_select "a[href*='/admin/screens/recording_studio_terms']", text: "Old versions"
    assert_select "a[href*='/admin/screens/recording_studio_terms_acceptances']", text: "Agree stats"
    refute_select "button", text: "New"
    refute_includes response.body, "Write terms"
    refute_includes response.body, "Every version"
    refute_includes response.body, "Who agreed"
    assert_includes response.body, "widget_view_variant=card"
    refute_includes response.body, "widget_view_variant=compact"
  end

  test "admin terms and who agreed screens stack widget title above the count" do
    sign_in @admin
    switch_to_workspace(@admin_root)

    get "/admin/screens/recording_studio_terms"
    assert_response :success
    assert_includes response.body, "Old versions"
    refute_includes response.body, "Table data"
    assert_includes response.body, "widget_view_variant=card"
    refute_includes response.body, "widget_view_variant=compact"

    get "/admin/screens/recording_studio_terms/widgets/widgets.terms.live",
        params: { widget_usage_index: 0, widget_view_variant: "card" },
        headers: { "Sec-Fetch-Dest" => "empty", "Turbo-Frame" => "widget" }
    assert_response :success
    assert_includes response.body, "Live terms"
    assert_includes response.body, "text-5xl"
    refute_includes response.body, "min-h-28"

    get "/admin/screens/recording_studio_terms_acceptances"
    assert_response :success
    assert_includes response.body, "Agree stats"
    assert_includes response.body, "Users"
    refute_includes response.body, "Table data"
    assert_includes response.body, "widget_view_variant=card"
    refute_includes response.body, "widget_view_variant=compact"

    get "/admin/screens/recording_studio_terms_acceptances/widgets/widgets.terms.agrees",
        params: { widget_usage_index: 0, widget_view_variant: "card" },
        headers: { "Sec-Fetch-Dest" => "empty", "Turbo-Frame" => "widget" }
    assert_response :success
    assert_includes response.body, "Agrees"
    assert_includes response.body, "text-5xl"
    refute_includes response.body, "min-h-28"
  end

  private

  def first_table_row_count
    table = css_select("table").find do |candidate|
      headers = candidate.css("thead th").map(&:text)
      headers.include?("Open") || headers.include?("Person")
    end
    return 0 unless table

    table.css("tbody tr").size
  end
end
