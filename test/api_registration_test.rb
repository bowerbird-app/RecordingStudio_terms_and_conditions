# frozen_string_literal: true

require "test_helper"

class ApiRegistrationTest < Minitest::Test
  def test_registration_is_nil_when_recording_studio_api_is_undefined
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudioTermsAndConditions::Api.register_capability_action!
  end

  def test_engine_registers_api_actions_before_the_api_initializer
    initializer = RecordingStudioTermsAndConditions::Engine.initializers.find do |candidate|
      candidate.name == "recording_studio_terms_and_conditions.register_recording_studio_api_action"
    end

    assert_equal "recording_studio_api.after_initialize", initializer.before
  end

  def test_registration_uses_each_api_view_role_and_openapi_titles
    source = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/api.rb", __dir__))

    assert_includes source, "configuration.each_api"
    assert_includes source, "register_capability_action(action_name, api: surface_name"
    assert_includes source, "required_role: :view"
    assert_includes source, "reject_unknown: false"
    assert_includes source, "capability: :terms_and_conditions"
    assert_includes source, 'title: "Terms - Accept"'
    assert_includes source, 'title: "Terms - Pending published list"'
    assert_includes source, 'title: "Terms - Current published"'
    assert_includes source, 'title: "Terms - Accepted"'
    assert_includes source, "AcceptPending"
    assert_includes source, "PendingPublishedList"
    assert_includes source, "CurrentPublishedFor"
    assert_includes source, "handler: Accepted"
    refute_includes source, "TermsWrite"
    refute_includes File.read(
      File.expand_path("../lib/recording_studio_terms_and_conditions/metrics.rb", __dir__)
    ), "register_capability_action"
  end

  def test_handlers_call_existing_domain_methods
    accept = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/api/accept_pending.rb", __dir__))
    pending = File.read(
      File.expand_path("../lib/recording_studio_terms_and_conditions/api/pending_published_list.rb", __dir__)
    )
    current = File.read(
      File.expand_path("../lib/recording_studio_terms_and_conditions/api/current_published_for.rb", __dir__)
    )
    accepted = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/api/accepted.rb", __dir__))

    assert_includes accept, "RecordingStudioTermsAndConditions.accept!"
    assert_includes accept, "pending_published_list"
    assert_includes pending, "pending_published_list"
    assert_includes current, "current_published_for"
    assert_includes accepted, "accepted?"
    authorize = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/api/actor_root.rb", __dir__))
    assert_includes authorize, "authorize!(recording: context.recording, role: :view)"
  end
end
