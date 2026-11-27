# frozen_string_literal: true

require "test_helper"

class OutlinePublishOrderTest < ActiveSupport::TestCase
  setup do
    @actor = User.create!(
      email: "outline-order-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @actor = library_writer(@actor)
    Current.actor = @actor
    @hooks = RecordingStudio.configuration.hooks
  end

  teardown do
    Current.actor = nil
    @hooks.clear(:around_service)
    @hooks.clear(RecordingStudioTermsAndConditions::OutlinePublish::LATCH)
    @hooks.clear(:recording_studio_broadcasts_sent_publishable_lock) if defined?(RecordingStudioBroadcasts)
    RecordingStudioTermsAndConditions::OutlinePublish.install!
  end

  test "a non-publishable service passes through the outline hook" do
    called = false
    result = @hooks.run_around(:around_service, Object.new) do
      called = true
      :performed
    end

    assert called
    assert_equal :performed, result
  end

  test "an outline release runs inside the broadcasts sent-publishable lock" do
    lock = broadcasts_lock
    recording = publish_seeded!("Keep the booth quiet.")
    RecordingStudioTermsAndConditions::Outline.edit_clause(
      RecordingStudioTermsAndConditions::Outline.sections(recording).first.clauses.first.recording,
      body: "Whisper.",
      actor: @actor
    )
    assert RecordingStudioTermsAndConditions::Outline.unreleased?(recording)

    lock.install!
    outline = RecordingStudioTermsAndConditions::OutlinePublish
    assert_operator outline::AROUND_PRIORITY, :>, lock::PRIORITY
    outer_seen = false
    watch_lock(lock) do |service|
      update = RecordingStudioPublishable::Services::Publishables::Update
      outer_seen = true if service.is_a?(update) && !Thread.current[outline::FLAG]
    end

    child = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "release-#{SecureRandom.hex(4)}", status: "published" },
      actor: @actor
    ).value!
    released = child.parent_recording

    assert outer_seen
    assert released.currently_published?
    assert_equal recording.id, released.id
    assert recording.reload.currently_published?
  end

  private

  def broadcasts_lock
    spec = Gem.loaded_specs.fetch("recording_studio_broadcasts")
    assert_equal Gem::Version.new("0.7.0"), spec.version
    require "recording_studio_broadcasts"
    register_broadcast_type
    root = File.join(spec.full_gem_path, "app/models/recording_studio_broadcasts")
    %w[publishable_write send_clock publishable_withdrawal campaign broadcast sent_publishable_lock].each do |name|
      path = File.join(root, "#{name}.rb")
      load path unless Object.const_defined?("RecordingStudioBroadcasts::#{name.camelize}")
    end
    RecordingStudioBroadcasts::SentPublishableLock
  end

  def register_broadcast_type
    configured = Array(RecordingStudio.configuration.recordable_types).map(&:to_s)
    RecordingStudio.configuration.recordable_types = (configured + ["RecordingStudioBroadcasts::Broadcast"]).uniq
  end

  def watch_lock(lock)
    entry = around_hooks.find { |hook| hook[:priority] == lock::PRIORITY }
    assert entry, "Broadcasts did not register its around_service lock"
    original = entry[:handler]
    entry[:handler] = lambda do |service, inner|
      yield service
      original.call(service, inner)
    end
  end

  def around_hooks
    @hooks.instance_variable_get(:@registry).fetch(:around_service)
  end

  def publish_seeded!(body)
    recording = record_terms(nil, title: "House rules", body: body, actor: @actor)
    publish_terms!(recording, slug: "house-#{SecureRandom.hex(4)}", actor: @actor)
    RecordingStudioTermsAndConditions::Outline.seed_recording!(recording, actor: @actor)
    recording.reload
  end
end
