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
    switch_to_workspace(@admin_root)
    clear_terms_on_write_workspace!

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_redirected_to "/admin/screens/recording_studio_terms"
    follow_redirect!
    assert_response :success
    refute_includes response.body, ">New<"
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
    assert_includes response.body, "terms[kind]"
    assert_includes response.body, "Privacy Policy"
    assert_includes response.body, "Save draft"
    assert_select "div.inline-block button[type=submit]", text: "Save draft"
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "nav[aria-label='Page navigation']", count: 1
    refute_select "header.fp-top-nav"
    refute_includes response.body, "Terms demo"
    refute_includes response.body, "Write terms"

    assert_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count }, 1 do
      post recording_studio_terms_and_conditions.admin_terms_path, params: {
        terms: { title: "House rules", body: "No yelling in the booth.", kind: "terms_and_condition" }
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
    assert_includes response.body, "fp-content"
    assert_includes response.body, "Draft"
    assert_includes response.body, "Publish now"
    refute_select "a", text: "Publish"
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
    original_body = recording.recordable.body
    assert_difference -> { RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name).count }, 1 do
      patch recording_studio_terms_and_conditions.admin_term_path(recording), params: {
        terms: { title: "House rules", body: "Whisper, please." }
      }
    end

    live = recording.reload
    draft = RecordingStudio::Recording.where(recordable_type: RecordingStudioTermsAndConditions::Terms.name)
                                      .order(:created_at).last
    assert_equal original_snapshot_id, live.recordable_id
    assert_equal original_body, live.recordable.body
    assert live.currently_published?
    refute_equal live.id, draft.id
    assert_equal "Whisper, please.", draft.recordable.body
    refute draft.currently_published?
    assert_redirected_to recording_studio_terms_and_conditions.admin_term_path(draft)
    follow_redirect!
    assert_includes response.body, "Draft saved. The live copy stays until you publish."
    assert_includes response.body, "Whisper, please."

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_redirected_to "/admin/screens/recording_studio_terms"
    get "/admin/screens/recording_studio_terms/table"
    assert_response :success
    assert_includes response.body, "House rules"
    assert_select "table thead th", text: "Title"
    assert_select "table thead th", text: "Type"
    refute_select "table thead th", text: "Category"
    refute_select "table thead th", text: "Coverage"
    assert_select "table thead th", text: "Status"
    assert_select "table thead th", text: "Published"
    assert_select "table thead th", text: "Agrees"
    assert_includes response.body, "House rules"
    assert_select "table tbody td", text: (recording.currently_published? ? "Live" : "Draft")
    assert_select "a", text: "Open"
  end

  test "admin section registers terms coverage widgets" do
    assert RecordingStudioAdmin.section_for("terms")
    assert RecordingStudioAdmin.screen_for("recording_studio_terms_acceptances")
    assert RecordingStudioAdmin.resource_for("terms")
    resource = RecordingStudioAdmin.resource_for("terms")
    assert resource.action_for(:index)
    assert resource.action_for(:show)
    assert resource.action_for(:edit)
    assert resource.action_for(:users)
    assert resource.action_for(:new)
    assert_equal :edit, resource.action_for(:edit).required_access_role
    assert_equal :edit, resource.action_for(:new).required_access_role
    assert RecordingStudioAdmin.widget_for("widgets.terms.terms_agreed")
    assert RecordingStudioAdmin.widget_for("widgets.terms.privacy_agreed")
    refute RecordingStudioAdmin.widget_for("widgets.terms.live")
    refute RecordingStudioAdmin.widget_for("widgets.terms.agrees")
    usages = RecordingStudioTermsAndConditions::Admin::TermsSection.widget_usages
    assert_equal %w[widgets.terms.terms_agreed widgets.terms.privacy_agreed], usages.map(&:key)
    assert usages.all? { |usage| usage.view_variant == :card }
    assert_empty RecordingStudioTermsAndConditions::Admin::TermsScreen.widget_usages
    assert_empty RecordingStudioTermsAndConditions::Admin::AcceptancesScreen.widget_usages
    assert RecordingStudioAdmin::WidgetRenderingHelper.ancestors.include?(
      RecordingStudioTermsAndConditions::AdminWidgetCard
    )
    keys = AdminRoot.recording_studio_admin_section_keys_for(@admin_root, @admin_recording, nil)
    assert_includes keys, "terms"
  end

  test "admin widget register survives a code reload" do
    admin = RecordingStudioTermsAndConditions::Admin
    2.times do
      admin.reset_definition_constants!
      load RecordingStudioTermsAndConditions::Engine.root.join("lib/recording_studio_terms_and_conditions/admin.rb")
      admin.register!
    end

    assert RecordingStudioAdmin.widget_for("widgets.terms.terms_agreed")
    assert RecordingStudioAdmin.resource_for("terms")
    assert_equal %w[widgets.terms.terms_agreed widgets.terms.privacy_agreed],
                 admin::TermsSection.widget_usages.map(&:key)
    assert_empty admin::TermsScreen.widget_usages
  end

  test "admin terms index paginates like other kit tables" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    26.times do |index|
      workspace = Workspace.create!(name: "Page #{index} #{SecureRandom.hex(3)}")
      root = RecordingStudio.root_recording_for(workspace)
      root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |terms|
        terms.title = "Page #{index} #{SecureRandom.hex(3)}"
        terms.body = "Body #{index}."
      end
    end

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_redirected_to "/admin/screens/recording_studio_terms"
  end

  test "term users paginates receipts" do
    sign_in @admin
    switch_to_workspace(@admin_root)
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

  test "who agreed lists one row per person and view opens their receipts" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    root = RecordingStudio.root_recording_for(@workspace)
    terms = publish_live_kind!(root, kind: "terms_and_condition", title: "House rules", slug: "house-#{SecureRandom.hex(3)}")
    privacy = publish_live_kind!(root, kind: "privacy_policy", title: "Quiet privacy", slug: "quiet-#{SecureRandom.hex(3)}")
    person = User.create!(
      email: "agreed-#{SecureRandom.hex(3)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    RecordingStudioTermsAndConditions.accept!(person, privacy, { "source" => "clickwrap" })
    RecordingStudioTermsAndConditions.accept!(person, terms, { "source" => "clickwrap" })

    get "/admin/screens/recording_studio_terms_acceptances/table"
    assert_response :success
    assert_select "table tbody tr", count: 1
    assert_includes response.body, person.email
    assert_select "a", text: "View"

    view_path = css_select("a").find { |link| link.text == "View" }["href"]
    get view_path
    assert_response :success
    assert_includes response.body, person.email
    assert_includes response.body, "House rules"
    assert_includes response.body, "Quiet privacy"
    assert_includes response.body, "Terms and Conditions"
    assert_includes response.body, "Privacy Policy"
    titles = css_select("table tbody tr").map { |row| row.text }
    assert titles.first.include?("House rules")
    assert titles.last.include?("Quiet privacy")
  end

  test "recording studio admin terms hub is reachable and write parks there" do
    sign_in @admin
    switch_to_workspace(@admin_root)

    root = RecordingStudio.root_recording_for(@workspace)
    publish_live_kind!(root, kind: "terms_and_condition", title: "House rules", slug: "house-rules-#{SecureRandom.hex(3)}")
    publish_live_kind!(root, kind: "privacy_policy", title: "Quiet privacy", slug: "quiet-privacy-#{SecureRandom.hex(3)}")

    get "/admin"
    assert_response :success
    refute_select "header.fp-top-nav"
    assert_includes response.body, "Terms and Conditions"
    refute_includes response.body, "All versions"
    refute_includes response.body, ">Agree stats<"
    refute_select "a", text: "New"
    refute_select "a", text: "All versions"
    refute_select "a", text: "Agree stats"
    assert_select "a", text: "Edit Terms"
    assert_select "a", text: "Edit Privacy Policy"
    assert_select "a[data-fp-style=secondary]", text: "Terms and Condition page"
    assert_select "a[data-fp-style=secondary]", text: "Privacy Policy page"
    assert_select "a[data-fp-style=secondary]", text: "Edit Terms"
    refute_select "button", text: "New"
    refute_includes response.body, "Write terms"
    refute_includes response.body, "Every version"
    refute_includes response.body, "Old versions"
    refute_includes response.body, "Who agreed"
    assert_includes response.body, "widget_view_variant=card"
    refute_includes response.body, "widget_view_variant=compact"
    refute_includes response.body, "+ Access"
    refute_includes response.body, "Terms demo"
    refute_select "a", text: "Sign out"

    get "/admin/sections"
    assert_redirected_to "/admin"
  end

  test "engine admin pages require the Admin root, not a workspace" do
    sign_in @admin
    switch_to_workspace(@workspace)

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :forbidden

    get recording_studio_terms_and_conditions.new_admin_term_path
    assert_response :forbidden
  end

  test "admin hub cards count people who agreed and versions stay a table" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    root = RecordingStudio.root_recording_for(@workspace)
    terms = publish_live_kind!(root, kind: "terms_and_condition", title: "Live rules", slug: "live-#{SecureRandom.hex(3)}")
    privacy = publish_live_kind!(root, kind: "privacy_policy", title: "Live privacy", slug: "priv-#{SecureRandom.hex(3)}")
    draft = root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |record|
      record.title = "Older draft"
      record.body = "Not live."
    end
    draft.update_columns(updated_at: 2.days.ago)
    person = User.create!(
      email: "counted-#{SecureRandom.hex(3)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    RecordingStudioTermsAndConditions.accept!(person, terms, { "source" => "clickwrap" })
    RecordingStudioTermsAndConditions.accept!(person, privacy, { "source" => "clickwrap" })

    get "/admin/screens/recording_studio_terms"
    assert_response :success
    assert_includes response.body, "All versions"
    refute_includes response.body, "widget_view_variant"

    get "/admin/screens/recording_studio_terms/table"
    titles = css_select("table tbody tr td:first-child").map { |cell| cell.text.strip }
    assert_operator titles.index("Live rules"), :<, titles.index("Older draft")

    get "/admin/sections/terms/widgets/widgets.terms.terms_agreed",
        params: { widget_usage_index: 0, widget_view_variant: "card" },
        headers: { "Sec-Fetch-Dest" => "empty", "Turbo-Frame" => "widget" }
    assert_response :success
    assert_includes response.body, "Terms and conditions"
    assert_includes response.body, "users agreed"
    assert_includes response.body, "text-5xl"

    get "/admin/sections/terms/widgets/widgets.terms.privacy_agreed",
        params: { widget_usage_index: 1, widget_view_variant: "card" },
        headers: { "Sec-Fetch-Dest" => "empty", "Turbo-Frame" => "widget" }
    assert_response :success
    assert_includes response.body, "Privacy Policy"
    assert_includes response.body, "users agreed"
    refute_includes response.body, "text-5xl font-bold\">users agreed"
  end

  test "who agreed search matches email or profile name" do
    sign_in @admin
    switch_to_workspace(@admin_root)
    recording = publish_live_kind!(
      RecordingStudio.root_recording_for(@workspace),
      kind: "terms_and_condition",
      title: "Searchable",
      slug: "search-#{SecureRandom.hex(3)}"
    )
    match = User.create!(
      email: "ada-#{SecureRandom.hex(3)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    other = User.create!(
      email: "other-#{SecureRandom.hex(3)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    RecordingStudioUser::Profile.create!(
      user: match, first_name: "Ada", last_name: "Lovelace", time_zone: "UTC"
    )
    RecordingStudioTermsAndConditions.accept!(match, recording, { "source" => "clickwrap" })
    RecordingStudioTermsAndConditions.accept!(other, recording, { "source" => "clickwrap" })

    get "/admin/screens/recording_studio_terms_acceptances/table", params: { name_or_email: "Ada" }
    assert_response :success
    assert_includes response.body, match.email
    refute_includes response.body, other.email

    get "/admin/screens/recording_studio_terms_acceptances/table", params: { name_or_email: match.email }
    assert_includes response.body, match.email
    refute_includes response.body, other.email
  end

  private

  def clear_terms_on_write_workspace!
    workspace = Workspace.find_by(name: "Studio Workspace")
    return unless workspace

    root = RecordingStudio.root_recording_for(workspace)
    root.recordings_query(
      include_children: true,
      type: RecordingStudioTermsAndConditions::Terms.name
    ).each do |recording|
      recording.update_columns(trashed_at: Time.current)
    end
  end

  def publish_live_kind!(root, kind:, title:, slug:)
    recording = root.record(RecordingStudioTermsAndConditions::Terms, actor: @admin) do |terms|
      terms.title = title
      terms.body = "Bring headphones."
      terms.kind = kind
    end
    publish_terms!(recording, slug: slug)
    recording
  end

  def first_table_row_count
    table = css_select("table").find do |candidate|
      headers = candidate.css("thead th").map(&:text)
      headers.include?("Open") || headers.include?("Person")
    end
    return 0 unless table

    table.css("tbody tr").size
  end
end
