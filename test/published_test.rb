# frozen_string_literal: true

require "test_helper"

class PublishedTest < Minitest::Test
  def setup
    RecordingStudioTermsAndConditions::Published.install!
    @events = []
    @subscriber = RecordingStudioTermsAndConditions::Published.subscribe do |event|
      @events << event.payload
    end
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
  end

  def test_terms_publish_emits_recording_id_and_terms_id
    instrument_publishable(recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE)

    assert_equal 1, @events.size
    assert_equal({ recording_id: "rec-1", terms_id: "terms-1" }, @events.first)
  end

  def test_other_recordable_publish_emits_nothing
    instrument_publishable(recordable_type: "Workspace")

    assert_empty @events
  end

  def test_unpublished_and_revised_emit_nothing
    ActiveSupport::Notifications.instrument(
      "unpublished.recording_studio_publishable",
      recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE,
      recording_id: "rec-1",
      recordable_id: "terms-1"
    )
    ActiveSupport::Notifications.instrument(
      "revised.recording_studio_publishable",
      recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE,
      recording_id: "rec-1",
      recordable_id: "terms-1"
    )

    assert_empty @events
  end

  def test_second_install_does_not_double_emit
    RecordingStudioTermsAndConditions::Published.install!
    instrument_publishable(recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE)

    assert_equal 1, @events.size
  end

  def test_removing_install_stops_the_event
    hooks = RecordingStudioPublishable.configuration.hooks
    hooks.clear(RecordingStudioTermsAndConditions::Published::LATCH)

    refute RecordingStudioTermsAndConditions::Published.installed?
    instrument_publishable(recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE)

    assert_empty @events
  ensure
    hooks.on(RecordingStudioTermsAndConditions::Published::LATCH) { true }
  end

  def test_lookup_record_error_is_logged_and_skips_the_event
    logs = []
    logger = Object.new
    logger.define_singleton_method(:error) { |message| logs << message.to_s }
    RecordingStudio::Recording.stub(:connected?, true) do
      RecordingStudio::Recording.stub(:find_by, ->(*) { raise ActiveRecord::StatementInvalid, "lookup failed" }) do
        Rails.stub(:logger, logger) do
          instrument_publishable(recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE)
        end
      end
    end

    assert_empty @events
    assert logs.any? { |line| line.include?("published subscriber failed") && line.include?("StatementInvalid") }
  end

  def test_subscriber_error_is_logged_and_does_not_raise
    logs = []
    logger = Object.new
    logger.define_singleton_method(:error) { |message| logs << message.to_s }
    reported = []
    reporter = Object.new
    reporter.define_singleton_method(:report) { |error, **_opts| reported << error }

    exploding = ActiveSupport::Notifications.subscribe(
      RecordingStudioTermsAndConditions::Published::EVENT
    ) { raise RuntimeError, "subscriber boom" }

    Rails.stub(:logger, logger) do
      Rails.stub(:error, reporter) do
        instrument_publishable(recordable_type: RecordingStudioTermsAndConditions::Published::TERMS_TYPE)
      end
    end

    assert_equal 1, reported.size
    assert_instance_of RuntimeError, reported.first
    assert logs.any? { |line| line.include?("subscriber boom") }
  ensure
    ActiveSupport::Notifications.unsubscribe(exploding) if exploding
  end

  private

  def instrument_publishable(recordable_type:)
    ActiveSupport::Notifications.instrument(
      "published.recording_studio_publishable",
      recordable_type: recordable_type,
      recording_id: "rec-1",
      recordable_id: "terms-1"
    )
  end
end
