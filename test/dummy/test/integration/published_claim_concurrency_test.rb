# frozen_string_literal: true

require "test_helper"

class PublishedClaimConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @workspace = Workspace.create!(name: "Claim #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
  end

  teardown do
    cleanup_claim_workspace(@workspace)
  end

  test "two concurrent claimants yield one win and one notification" do
    claim_recording = publish_without_terms_event("Claim body")
    notify_recording = publish_without_terms_event("Notify body")
    events = []
    subscriber = RecordingStudioTermsAndConditions::Published.subscribe do |event|
      events << event.payload
    end

    threaded_results(2) do
      ActiveSupport::Notifications.instrument(
        "published.recording_studio_publishable",
        recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE,
        recording_id: claim_recording.id,
        recordable_id: claim_recording.recordable.id
      )
    end
    threaded_results(2) do
      ActiveSupport::Notifications.instrument(
        "published.recording_studio_publishable",
        recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE,
        recording_id: notify_recording.id,
        recordable_id: notify_recording.recordable.id
      )
    end

    recording_ids = events.map { |payload| payload.fetch(:recording_id) }
    assert_equal 1, recording_ids.count(claim_recording.id)
    assert_equal 1, recording_ids.count(notify_recording.id)
    assert_equal 2, events.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  private

  def cleanup_claim_workspace(workspace)
    return if workspace.blank?

    root = RecordingStudio::Recording.find_by(recordable: workspace)
    if root
      ids = RecordingStudio::Recording.where(root_recording_id: root.id).pluck(:id) + [root.id]
      RecordingStudio::Event.where(recording_id: ids).delete_all
      RecordingStudio::Recording.where(id: ids).delete_all
    end
    workspace.delete
  end

  def publish_without_terms_event(body)
    hooks = RecordingStudioPublishable.configuration.hooks
    recording = @root.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = "Live"
      terms.body = body
    end
    hooks.clear(RecordingStudioTermsAndConditions::Published::LATCH)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "claim-#{SecureRandom.hex(4)}", status: "published" }
    ).value!
    recording.reload
  ensure
    hooks.on(RecordingStudioTermsAndConditions::Published::LATCH) { true }
  end

  def threaded_results(count)
    queue = Queue.new
    start = Queue.new
    threads = Array.new(count) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          queue << yield
        end
      end
    end
    count.times { start << true }
    threads.each(&:join)
    Array.new(count) { queue.pop }
  end
end
