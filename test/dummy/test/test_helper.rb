# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module TermsDemoTestHelper
  def bootstrap_owner_access!(actor, recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return result.value if result.respond_to?(:success?) && result.success?

    if already_bootstrapped?(result)
      manager = User.find_by(email: "admin@admin.com")
      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: :admin,
        manager_actor: manager
      )
    end

    raise result.error if result.respond_to?(:failure?) && result.failure?

    result.respond_to?(:value) ? result.value : result
  end

  def already_bootstrapped?(result)
    result.error.to_s.include?("Access already exists")
  end

  def recording_write_actor
    actor = Current.actor || User.find_by(email: "admin@admin.com") || User.create!(
      email: "writer-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = actor if defined?(Current) && Current.respond_to?(:actor=)
    actor
  end

  def grant_workspace_access!(actor, workspace)
    recording = RecordingStudio.root_recording_for(workspace)
    return recording if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

    bootstrap_owner_access!(actor, recording)
  end

  def record_terms(root_recording, title:, body:, kind: RecordingStudioTermsAndConditions::Terms::DEFAULT_KIND, actor: nil)
    writer = actor || recording_write_actor
    root_recording.record(RecordingStudioTermsAndConditions::Terms, actor: writer) do |terms|
      terms.title = title
      terms.body = body
      terms.kind = kind
    end
  end

  def publish_terms!(recording, slug:, status: "published")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: status },
      actor: recording_write_actor
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

  def without_live_terms_fallback
    gate = RecordingStudioTermsAndConditions::Gate
    original = gate.method(:first_root_with_live_terms)
    gate.define_singleton_method(:first_root_with_live_terms) { |_actor = nil| nil }
    yield
  ensure
    gate.define_singleton_method(:first_root_with_live_terms, original)
  end
end

class ActiveSupport::TestCase
  include TermsDemoTestHelper
end
