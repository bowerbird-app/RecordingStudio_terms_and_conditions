# frozen_string_literal: true

require "test_helper"

class PublishedTermsTest < ActionDispatch::IntegrationTest
  test "published terms are at the public Publishable path" do
    workspace = Workspace.create!(name: "Public #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    recording = record_terms(root, title: "Studio Terms", body: "Be kind. Don't be a jerk.")
    publish_terms!(recording, slug: "studio-terms-#{SecureRandom.hex(4)}")
    publishable = recording.publishable_child_recording
    slug = publishable.recordable.slug

    get "/terms/#{publishable.id}/#{slug}"

    assert_response :success
    assert_includes response.body, "Studio Terms"
    assert_includes response.body, "Be kind"
    assert_includes response.body, "flat-pack-content-editor-content"
    published_on = recording.current_publishable.publish_at.in_time_zone.strftime("%e %b %Y").squish
    assert_includes response.body, published_on
    refute_includes response.body, "ago"
    assert_includes response.body, 'data-theme="rounded"'
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_match %r{flat_pack/application}, response.body
    refute_includes response.body, "I agree to these terms"
    refute_includes response.body, "max-w-3xl"
  end

  test "draft terms are not on the public path" do
    workspace = Workspace.create!(name: "Draft #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    recording = record_terms(root, title: "Hidden", body: "Not live.")
    publish_terms!(recording, slug: "hidden-terms-#{SecureRandom.hex(4)}", status: "draft")
    publishable = recording.publishable_child_recording
    slug = publishable.recordable.slug

    get "/terms/#{publishable.id}/#{slug}"

    assert_response :not_found
  end
end
