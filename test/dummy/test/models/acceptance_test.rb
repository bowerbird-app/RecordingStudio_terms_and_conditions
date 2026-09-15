# frozen_string_literal: true

require "test_helper"

class AcceptanceTest < ActiveSupport::TestCase
  test "acceptance is a gem-owned table and not a recordable type" do
    connection = ActiveRecord::Base.connection
    configured = Array(RecordingStudio.configuration.recordable_types).map(&:to_s)

    assert connection.table_exists?(:recording_studio_terms_and_conditions_acceptances)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :actor_type)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :actor_id)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :terms_recording_id)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :terms_id)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :accepted_at)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :body_digest)
    assert connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :created_at)
    refute connection.column_exists?(:recording_studio_terms_and_conditions_acceptances, :updated_at)
    refute_includes configured, "RecordingStudioTermsAndConditions::Acceptance"
    refute RecordingStudio.recordable_declaration_defined?("RecordingStudioTermsAndConditions::Acceptance")
    unique = connection.indexes(:recording_studio_terms_and_conditions_acceptances).find do |index|
      index.name == "index_rstac_acceptances_on_actor_and_version"
    end
    assert unique.unique
    assert_equal %w[actor_type actor_id terms_recording_id terms_id], unique.columns
  end

  test "acceptance stores an immutable receipt for an actor and terms version" do
    user = User.create!(email: "terms-#{SecureRandom.hex(4)}@example.com", password: "Password",
                        password_confirmation: "Password")
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: "Accept #{SecureRandom.hex(4)}"))
    event = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioTermsAndConditions::Terms.new(title: "Clickwrap", body: "I agree."),
      root_recording: root_recording,
      parent_recording: root_recording
    )
    terms = event.recording.recordable

    receipt = RecordingStudioTermsAndConditions::Acceptance.create!(
      actor: user,
      terms_recording_id: event.recording.id,
      terms_id: terms.id,
      accepted_at: Time.current,
      body_digest: RecordingStudioTermsAndConditions::BodyDigest.call(terms.body)
    )

    assert_predicate receipt, :persisted?
    assert_predicate receipt, :readonly?
    assert_equal user, receipt.actor
    assert_equal event.recording.id, receipt.terms_recording_id
    assert_equal terms.id, receipt.terms_id
    assert_equal RecordingStudioTermsAndConditions::BodyDigest.call(terms.body), receipt.body_digest
    assert_equal "sha256", receipt.receipt_contract.fetch("body_digest_algorithm")
    assert_raises(ActiveRecord::ReadOnlyRecord) { receipt.update!(accepted_at: 1.day.ago) }
  end
end
