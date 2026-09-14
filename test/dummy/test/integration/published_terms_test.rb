# frozen_string_literal: true

require "test_helper"

class PublishedTermsTest < ActionDispatch::IntegrationTest
  test "published terms are at the public Publishable path" do
    workspace = Workspace.find_by!(name: "Studio Workspace")
    terms = RecordingStudioTermsAndConditions.current_published_for(workspace)
    recording = RecordingStudio::Recording.find_by!(recordable: terms)
    publishable = recording.publishable_child_recording

    get "/terms/#{publishable.id}/studio-terms"

    assert_response :success
    assert_includes response.body, "Studio Terms"
    assert_includes response.body, "Be kind"
    assert_includes response.body, 'data-theme="rounded"'
    refute_includes response.body, "I agree to these terms"
  end

  test "draft terms are not on the public path" do
    workspace = Workspace.create!(name: "Public #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    recording = root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = "Hidden"
      terms.body = "Not live."
    end
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "hidden-terms", status: "draft" }
    ).value!
    publishable = recording.publishable_child_recording

    get "/terms/#{publishable.id}/hidden-terms"

    assert_response :not_found
  end
end
