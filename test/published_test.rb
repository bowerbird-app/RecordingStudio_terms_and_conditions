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
    source = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/published.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/engine.rb", __dir__))

    assert_includes source, "published.recording_studio_terms_and_conditions"
    assert_includes source, "RecordingStudioPublishable.subscribe(:published)"
    assert_includes engine, "RecordingStudioTermsAndConditions::Published.install!"
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
