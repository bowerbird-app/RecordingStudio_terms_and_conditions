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

  def grant_write_access!(recording, actor = nil)
    writer = actor || recording_write_actor
    return writer if recording.blank?

    root = recording.respond_to?(:root_recording) ? (recording.root_recording || recording) : recording
    return writer if RecordingStudioAccessible.authorized?(actor: writer, recording: root, role: :edit)

    admin = held_access_admin
    ensure_held_admin_on!(root, admin)
    return writer if writer == admin || RecordingStudioAccessible.authorized?(actor: writer, recording: root, role: :edit)

    grant_through_admin!(root, writer, admin)
    writer
  end

  def held_access_admin
    User.find_by(email: "admin@admin.com") || User.create!(
      email: "admin@admin.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  def ensure_held_admin_on!(root, admin)
    return if RecordingStudioAccessible.authorized?(actor: admin, recording: root, role: :admin)

    existing = access_admin_for(root)
    if existing
      grant_through_admin!(root, admin, existing) unless existing == admin
      return
    end

    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: admin)
    return if result.respond_to?(:success?) && result.success?
    if already_bootstrapped?(result)
      manager = access_admin_for(root)
      raise result.error unless manager

      grant_through_admin!(root, admin, manager) unless manager == admin
      return
    end

    raise result.error if result.respond_to?(:failure?) && result.failure?
  end

  def grant_through_admin!(root, actor, admin)
    previous_actor = Current.actor if defined?(Current)
    begin
      Current.actor = admin if defined?(Current) && Current.respond_to?(:actor=)
      result = RecordingStudioAccessible.grant_access(
        recording: root,
        actor: actor,
        role: :admin,
        manager_actor: admin
      )
      raise result.error if result.respond_to?(:failure?) && result.failure?
    ensure
      Current.actor = previous_actor if defined?(Current) && Current.respond_to?(:actor=)
    end
  end

  def access_admin_for(recording)
    return unless RecordingStudioAccessible.respond_to?(:access_recordings_for)

    RecordingStudioAccessible.access_recordings_for(recording).each do |access_recording|
      access = access_recording.recordable
      next unless access.respond_to?(:role) && access.role.to_s == "admin"
      next unless access.respond_to?(:actor) && access.actor

      return access.actor
    end
    nil
  end

  def grant_workspace_access!(actor, workspace)
    recording = RecordingStudio.root_recording_for(workspace)
    return recording if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

    bootstrap_owner_access!(actor, recording)
  end

  def record_terms(root_recording, title:, body:, kind: RecordingStudioTermsAndConditions::Terms::DEFAULT_KIND, actor: nil)
    writer = actor || recording_write_actor
    grant_write_access!(root_recording, writer)
    root_recording.record(RecordingStudioTermsAndConditions::Terms, actor: writer) do |terms|
      terms.title = title
      terms.body = body
      terms.kind = kind
    end
  end

  def publish_terms!(recording, slug:, status: "published", actor: nil)
    writer = actor || recording_write_actor
    grant_write_access!(recording, writer)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: status },
      actor: writer
    ).value!
  end

  def switch_to_workspace(workspace)
    # Root Switchable 0.12+ returns 403 unless the signed-in actor holds
    # Accessible :view on the current root. Dummy's scope still lists every
    # root; the page floor is the new requirement.
    grant_current_root_view!(@terms_signed_in_user)
    grant_view_access!(@terms_signed_in_user, workspace) if @terms_signed_in_user && workspace

    recording = RecordingStudio.root_recording_for(workspace)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: recording.id,
        return_to: "/"
      }
    }
  end

  def grant_view_access!(actor, recordable)
    return unless actor && recordable

    recording = if recordable.is_a?(RecordingStudio::Recording)
                  recordable
                else
                  RecordingStudio.root_recording_for(recordable)
                end
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

    manager = access_admin_for(recording)
    if manager && manager != actor
      previous_actor = Current.actor if defined?(Current)
      begin
        Current.actor = manager if defined?(Current) && Current.respond_to?(:actor=)
        result = RecordingStudioAccessible.grant_access(
          recording: recording,
          actor: actor,
          role: :view,
          manager_actor: manager
        )
        raise result.error if result.respond_to?(:failure?) && result.failure?
      ensure
        Current.actor = previous_actor if defined?(Current) && Current.respond_to?(:actor=)
      end
      return
    end

    bootstrap_owner_access!(actor, recording)
  end

  def grant_current_root_view!(actor)
    return unless actor

    RecordingStudio::RootSwitchable::Selection.where(actor: actor).find_each do |selection|
      recordable = selection.root_recording&.recordable
      grant_view_access!(actor, recordable) if recordable
    end

    current = dummy_default_switch_root
    grant_view_access!(actor, current.recordable) if current&.recordable
  end

  def dummy_default_switch_root
    admin = AdminRoot.find_by(name: "Admin")
    admin_recording = admin && RecordingStudio.root_recording_for(admin)
    workspace_roots = Workspace.order(:name).filter_map do |workspace|
      RecordingStudio.root_recording_for(workspace)
    end
    roots = [admin_recording, *workspace_roots].compact
    roots.find { |root| root.recordable.try(:name) == "Studio Workspace" } || roots.first
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

module TermsSignInTracker
  def sign_in(resource, *args, **kwargs)
    @terms_signed_in_user = resource if resource.is_a?(User)
    super
  end
end

class ActionDispatch::IntegrationTest
  def self.inherited(subclass)
    super
    subclass.prepend(TermsSignInTracker)
  end
end

class ActiveSupport::TestCase
  include TermsDemoTestHelper
end
