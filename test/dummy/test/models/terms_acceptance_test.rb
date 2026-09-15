# frozen_string_literal: true

require "test_helper"

class TermsAcceptanceTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: unique_name("Terms root"))
    @other_workspace = Workspace.create!(name: unique_name("Other root"))
    @root = RecordingStudio.root_recording_for(@workspace)
    @other_root = RecordingStudio.root_recording_for(@other_workspace)
    @actor = User.create!(
      email: "accept-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @other_actor = User.create!(
      email: "other-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  test "current_published_for returns live published Terms for a host root" do
    recording = record_terms("Live terms", "Be kind.")
    publish_terms!(recording, slug: "live-terms")
    privacy = record_terms("Privacy", "Cookies stay in the booth.", kind: "privacy")
    publish_terms!(privacy, slug: "privacy-policy")

    published = RecordingStudioTermsAndConditions.current_published_for(@workspace)

    assert_equal recording.recordable, published
    assert_equal "Live terms", published.title
    assert_equal "terms", published.kind
    assert_equal privacy.recordable,
                 RecordingStudioTermsAndConditions.current_published_for(@workspace, kind: "privacy")
    assert_nil RecordingStudioTermsAndConditions.current_published_for(@other_workspace)
    assert_equal published, RecordingStudioTermsAndConditions.current_published_for(@root)
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace, kind: "usage")
  end

  test "current_published_for ignores a draft terms recording" do
    record_terms("Draft", "Not live.")

    assert_nil RecordingStudioTermsAndConditions.current_published_for(@workspace)
  end

  test "current_published_for ignores scheduled Terms that are not live yet" do
    recording = record_terms("Soon", "Wait.")
    publish_terms!(recording, slug: "soon-terms", publish_at: 1.day.from_now)

    assert_nil RecordingStudioTermsAndConditions.current_published_for(@workspace)
  end

  test "accepted? and requires_acceptance? follow the current published version" do
    recording = record_terms("Clickwrap", "I agree.")
    publish_terms!(recording, slug: "clickwrap")

    assert RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
    refute RecordingStudioTermsAndConditions.accepted?(@actor, @workspace)
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @other_workspace)

    live = recording.recordable
    expected_digest = RecordingStudioTermsAndConditions::BodyDigest.call(live.body)
    receipt = RecordingStudioTermsAndConditions.accept!(
      @actor,
      recording,
      { "source" => "clickwrap", "ip" => "203.0.113.10" }
    )

    assert_predicate receipt, :readonly?
    assert_equal({ "source" => "clickwrap", "ip" => "203.0.113.10" }, receipt.provenance)
    assert_equal expected_digest, receipt.body_digest
    assert_equal expected_digest, receipt.receipt_contract.fetch("body_digest")
    assert_equal "sha256", receipt.receipt_contract.fetch("body_digest_algorithm")
    assert_equal live.id.to_s, receipt.receipt_contract.fetch("terms_id")
    refute receipt.provenance.key?("body_digest")
    assert RecordingStudioTermsAndConditions.accepted?(@actor, @workspace)
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
    refute RecordingStudioTermsAndConditions.accepted?(@other_actor, @workspace)
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@other_actor, @workspace)
  end

  test "accept! records the Terms snapshot so a later revision requires acceptance again" do
    recording = record_terms("v1", "First.")
    publish_terms!(recording, slug: "versioned-terms")
    first = recording.recordable

    RecordingStudioTermsAndConditions.accept!(@actor, first, source: "clickwrap")
    assert RecordingStudioTermsAndConditions.accepted?(@actor, @workspace)

    revised = @root.revise(recording) { |terms| terms.body = "Second." }
    publish_terms!(revised, slug: "versioned-terms")

    refute RecordingStudioTermsAndConditions.accepted?(@actor, @workspace)
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
    assert_equal "Second.", RecordingStudioTermsAndConditions.current_published_for(@workspace).body
  end

  test "accept! requires an actor and a Terms version" do
    recording = record_terms("Need actor", "Yes.")
    publish_terms!(recording, slug: "need-actor")

    assert_raises(ArgumentError) { RecordingStudioTermsAndConditions.accept!(nil, recording, {}) }
    assert_raises(ArgumentError) { RecordingStudioTermsAndConditions.accept!(@actor, @workspace, {}) }
    assert_raises(ArgumentError) { RecordingStudioTermsAndConditions.accept!(@actor, recording, "clickwrap") }
  end

  test "accept! refuses drafts, unpublished, and scheduled terms" do
    draft = record_terms("Draft", "Not live.")
    soon = record_terms("Soon", "Wait.", kind: "privacy")
    publish_terms!(soon, slug: "soon-refuse", publish_at: 1.day.from_now)
    unpublished = record_terms("Was live", "Gone.", kind: "usage")
    publish_terms!(unpublished, slug: "was-live")
    publish_terms!(unpublished, slug: "was-live", status: "draft")

    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      assert_raises(RecordingStudioTermsAndConditions::NotLive) do
        RecordingStudioTermsAndConditions.accept!(@actor, draft, source: "clickwrap")
      end
      assert_raises(RecordingStudioTermsAndConditions::NotLive) do
        RecordingStudioTermsAndConditions.accept!(@actor, soon, source: "clickwrap")
      end
      assert_raises(RecordingStudioTermsAndConditions::NotLive) do
        RecordingStudioTermsAndConditions.accept!(@actor, unpublished, source: "clickwrap")
      end
    end
  end

  test "accept! ignores a caller body_digest and never rewrites an older receipt" do
    recording = record_terms("Digest", "Live copy.")
    publish_terms!(recording, slug: "digest-terms")
    terms = recording.recordable
    older = RecordingStudioTermsAndConditions::Acceptance.create!(
      actor: @other_actor,
      terms_recording_id: recording.id,
      terms_id: terms.id,
      accepted_at: Time.current,
      body_digest: nil,
      provenance: { "source" => "legacy" }
    )

    receipt = RecordingStudioTermsAndConditions.accept!(
      @actor,
      terms,
      { "source" => "clickwrap", "body_digest" => "sha256:spoofed" }
    )

    older.reload
    assert_nil older.body_digest
    assert_equal({ "source" => "legacy" }, older.provenance)
    assert_equal RecordingStudioTermsAndConditions::BodyDigest.call("Live copy."), receipt.body_digest
    refute receipt.provenance.key?("body_digest")
    assert_raises(ActiveRecord::ReadOnlyRecord) { older.update!(body_digest: receipt.body_digest) }
  end

  test "accept! returns the existing receipt for the same actor and snapshot" do
    recording = record_terms("Once", "One tick.")
    publish_terms!(recording, slug: "once-terms")
    first = RecordingStudioTermsAndConditions.accept!(
      @actor,
      recording,
      { "source" => "clickwrap", "attempt" => "1" }
    )

    second = nil
    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      second = RecordingStudioTermsAndConditions.accept!(
        @actor,
        recording,
        { "source" => "retry", "attempt" => "2" }
      )
    end

    assert_equal first.id, second.id
    assert_equal first.body_digest, second.body_digest
    assert_equal({ "source" => "clickwrap", "attempt" => "1" }, second.provenance)
    assert_equal first.receipt_contract, second.receipt_contract
    assert_raises(ActiveRecord::RecordNotUnique) do
      RecordingStudioTermsAndConditions::Acceptance.create!(
        actor: @actor,
        terms_recording_id: recording.id,
        terms_id: recording.recordable.id,
        accepted_at: Time.current,
        body_digest: first.body_digest
      )
    end
  end

  test "accept! inserts a new receipt after a later published revision" do
    recording = record_terms("v1", "First.")
    publish_terms!(recording, slug: "retry-versioned")
    first = RecordingStudioTermsAndConditions.accept!(@actor, recording, source: "clickwrap")

    revised = @root.revise(recording) { |terms| terms.body = "Second." }
    publish_terms!(revised, slug: "retry-versioned")
    second = RecordingStudioTermsAndConditions.accept!(@actor, revised, source: "clickwrap")

    assert_not_equal first.id, second.id
    assert_not_equal first.terms_id, second.terms_id
    assert_equal RecordingStudioTermsAndConditions::BodyDigest.call("First."), first.body_digest
    assert_equal RecordingStudioTermsAndConditions::BodyDigest.call("Second."), second.body_digest
    first.reload
    assert_equal "First.", RecordingStudioTermsAndConditions::Terms.find(first.terms_id).body
  end

  test "reaccepting? is true only after an older snapshot and a new live version" do
    recording = record_terms("v1", "First.")
    publish_terms!(recording, slug: "reaccept-#{SecureRandom.hex(4)}")

    refute RecordingStudioTermsAndConditions.reaccepting?(@actor, @workspace)
    RecordingStudioTermsAndConditions.accept!(@actor, recording, source: "clickwrap")
    refute RecordingStudioTermsAndConditions.reaccepting?(@actor, @workspace)

    revised = @root.revise(recording) { |terms| terms.body = "Second." }
    publish_terms!(revised, slug: "reaccept-#{SecureRandom.hex(4)}")

    assert RecordingStudioTermsAndConditions.reaccepting?(@actor, @workspace)
    refute RecordingStudioTermsAndConditions.accepted?(@actor, @workspace)
  end

  test "current_published_by_kind maps live kinds and requires_acceptance? covers any of them" do
    terms = record_terms("Live terms", "Be kind.")
    publish_terms!(terms, slug: "live-terms-map")
    privacy = record_terms("Privacy", "Keep the tape.", kind: "privacy")
    publish_terms!(privacy, slug: "privacy-map")

    by_kind = RecordingStudioTermsAndConditions.current_published_by_kind(@workspace)

    assert_equal %w[terms privacy], by_kind.keys
    assert_equal terms.recordable, by_kind.fetch("terms")
    assert_equal privacy.recordable, by_kind.fetch("privacy")
    assert_empty RecordingStudioTermsAndConditions.current_published_by_kind(@other_workspace)
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace, kind: "privacy")

    RecordingStudioTermsAndConditions.accept!(@actor, terms, source: "clickwrap")
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace, kind: "terms")
    refute RecordingStudioTermsAndConditions.requires_acceptance?(
      @actor, @workspace, required_kinds: ["terms"]
    )
    assert RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
    refute RecordingStudioTermsAndConditions.accepted?(@actor, @workspace, kind: "privacy")
    assert RecordingStudioTermsAndConditions.accepted?(@actor, @workspace)

    RecordingStudioTermsAndConditions.accept!(@actor, privacy, source: "clickwrap")
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
    assert RecordingStudioTermsAndConditions.accepted?(@actor, @workspace, kind: "privacy")
  end

  test "pending_published_list returns live kinds the actor still needs" do
    terms = record_terms("Live terms", "Be kind.")
    publish_terms!(terms, slug: "pending-list-terms")
    privacy = record_terms("Privacy", "Keep the tape.", kind: "privacy")
    publish_terms!(privacy, slug: "pending-list-privacy")

    pending = RecordingStudioTermsAndConditions.pending_published_list(@actor, @workspace)

    assert_equal [terms.recordable, privacy.recordable], pending
    RecordingStudioTermsAndConditions.accept!(@actor, terms, source: "clickwrap")
    assert_equal [privacy.recordable],
                 RecordingStudioTermsAndConditions.pending_published_list(@actor, @workspace)
    assert_equal privacy.recordable,
                 RecordingStudioTermsAndConditions.pending_published_for(@actor, @workspace)
  end

  test "required_kinds and config.required_kinds narrow the gate" do
    previous = RecordingStudioTermsAndConditions.configuration.required_kinds
    terms = record_terms("Live terms", "Be kind.")
    publish_terms!(terms, slug: "live-terms-narrow")
    privacy = record_terms("Privacy", "Keep the tape.", kind: "privacy")
    publish_terms!(privacy, slug: "privacy-narrow")
    RecordingStudioTermsAndConditions.accept!(@actor, terms, source: "clickwrap")

    assert RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
    refute RecordingStudioTermsAndConditions.requires_acceptance?(
      @actor, @workspace, required_kinds: %w[terms]
    )
    assert RecordingStudioTermsAndConditions.requires_acceptance?(
      @actor, @workspace, required_kinds: %w[privacy]
    )

    RecordingStudioTermsAndConditions.configuration.required_kinds = %w[terms]
    refute RecordingStudioTermsAndConditions.requires_acceptance?(@actor, @workspace)
  ensure
    RecordingStudioTermsAndConditions.configuration.required_kinds = previous
  end

  private

  def record_terms(title, body, kind: RecordingStudioTermsAndConditions::Terms::DEFAULT_KIND)
    RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioTermsAndConditions::Terms.new(title: title, body: body, kind: kind),
      root_recording: @root,
      parent_recording: @root
    ).recording
  end

  def publish_terms!(recording, slug:, status: "published", publish_at: nil)
    attributes = { slug: slug, status: status }
    attributes[:publish_at] = publish_at if publish_at
    result = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: attributes
    )
    result.value!
  end

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
