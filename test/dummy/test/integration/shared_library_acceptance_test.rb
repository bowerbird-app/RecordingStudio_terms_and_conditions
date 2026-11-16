# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SharedLibraryAcceptanceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "shared-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @first = Workspace.create!(name: "One #{SecureRandom.hex(4)}")
    @second = Workspace.create!(name: "Two #{SecureRandom.hex(4)}")
    grant_workspace_access!(@user, @first)
    grant_workspace_access!(@user, @second)
  end

  test "a person accepts once and switching workspace does not ask again" do
    publish_shared!("Once")
    sign_in @user
    switch_to_workspace(@first)

    get "/"
    assert_redirected_to acceptance_path
    post acceptance_path
    assert_redirected_to "/"
    follow_redirect!
    assert_response :success

    switch_to_workspace(@second)
    get "/"
    assert_response :success
    refute_redirected_to_acceptance
    assert RecordingStudioTermsAndConditions.accepted?(@user)
  end

  test "publishing a new version asks once" do
    recording = publish_shared!("Versioned")
    sign_in @user
    switch_to_workspace(@first)
    post acceptance_path
    follow_redirect!
    assert_response :success

    revised = recording.root_recording.revise(recording, actor: library_writer) do |terms|
      terms.body = "Be kinder."
    end
    publish_terms!(revised, slug: "shared-v2-#{SecureRandom.hex(4)}")

    get "/"
    assert_redirected_to acceptance_path
    post acceptance_path
    follow_redirect!
    assert_response :success

    switch_to_workspace(@second)
    get "/"
    assert_response :success
    refute_redirected_to_acceptance
    assert RecordingStudioTermsAndConditions.accepted?(@user)
  end

  test "a person with no workspace access is still gated by the shared library" do
    publish_shared!("No booth")
    outsider = User.create!(
      email: "no-booth-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in outsider

    get "/"
    assert_redirected_to acceptance_path
    follow_redirect!
    assert_includes response.body, "No booth"

    post acceptance_path
    assert_redirected_to "/"
    follow_redirect!
    assert_response :success
    get "/"
    assert_response :success
    refute_redirected_to_acceptance
  end

  private

  def publish_shared!(title)
    recording = record_terms(title: title, body: "Be kind.")
    publish_terms!(recording, slug: "shared-#{SecureRandom.hex(4)}")
    recording
  end

  def acceptance_path
    recording_studio_terms_and_conditions.acceptance_path
  end

  def refute_redirected_to_acceptance
    refute_equal acceptance_path, response.redirect_url.to_s.split("?").first
  end
end
