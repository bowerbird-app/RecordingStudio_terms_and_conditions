# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module TermsDemoTestHelper
  def bootstrap_owner_access!(actor, recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return result.value if result.respond_to?(:success?) && result.success?
    raise result.error if result.respond_to?(:failure?) && result.failure?

    result
  end

  def record_terms(root_recording, title:, body:)
    root_recording.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = title
      terms.body = body
    end
  end

  def publish_terms!(recording, slug:, status: "published")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: status }
    ).value!
  end

  def switch_to_workspace(workspace)
    recording = RecordingStudio.root_recording_for(workspace)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: recording.id,
        return_to: "/"
      }
    }
  end
end

class ActionDispatch::IntegrationTest
  include TermsDemoTestHelper
end
