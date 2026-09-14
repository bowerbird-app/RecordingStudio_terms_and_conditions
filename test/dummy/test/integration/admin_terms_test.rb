# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminTermsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    @member = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(@admin_root)
  end

  test "admin without access is forbidden" do
    sign_in @member

    get recording_studio_terms_and_conditions.admin_terms_path

    assert_response :forbidden
  end

  test "admin can draft and revise terms" do
    sign_in @admin

    get recording_studio_terms_and_conditions.admin_terms_path
    assert_response :success
    assert_includes response.body, "Write terms"

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
    assert_includes response.body, "House rules"
    assert_includes response.body, "Publish"

    patch recording_studio_terms_and_conditions.admin_term_path(recording), params: {
      terms: { title: "House rules", body: "Whisper, please." }
    }

    revised = recording.reload
    assert_equal "Whisper, please.", revised.recordable.body
    follow_redirect!
    assert_includes response.body, "Terms updated."
  end

  test "admin section registers terms coverage widgets" do
    sign_in @admin

    get recording_studio_admin_admin.section_path("terms")

    assert_response :success
    assert_includes response.body, "Live terms"
    assert_includes response.body, "Agrees"
  end
end
