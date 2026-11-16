# frozen_string_literal: true

require "test_helper"

class OutlinePublishHooksTest < Minitest::Test
  def setup
    @hooks = RecordingStudio.configuration.hooks
  end

  def teardown
    restore_service_hooks
  end

  def test_a_non_publishable_service_passes_through
    RecordingStudioTermsAndConditions::OutlinePublish.install!
    service = Object.new
    called = false

    result = @hooks.run_around(:around_service, service) do
      called = true
      :performed
    end

    assert called
    assert_equal :performed, result
  end

  def test_clear_resets_the_latches_and_install_registers_them_again
    @hooks.clear!
    outline = RecordingStudioTermsAndConditions::OutlinePublish
    sole_live = RecordingStudioTermsAndConditions::SoleLive
    published = RecordingStudioTermsAndConditions::Published

    refute @hooks.registered?(outline::LATCH)
    refute @hooks.registered?(sole_live::HOOK_EVENT)
    refute @hooks.registered?(published::LATCH)

    outline.install!
    sole_live.install!
    published.install!

    assert @hooks.registered?(outline::LATCH)
    assert @hooks.registered?(sole_live::HOOK_EVENT)
    assert @hooks.registered?(published::LATCH)
  end

  private

  def restore_service_hooks
    @hooks.clear(:around_service)
    @hooks.clear(:after_service)
    [
      RecordingStudioTermsAndConditions::OutlinePublish::LATCH,
      RecordingStudioTermsAndConditions::SoleLive::HOOK_EVENT,
      RecordingStudioTermsAndConditions::Published::LATCH
    ].each { |latch| @hooks.clear(latch) }
    RecordingStudioTermsAndConditions::OutlinePublish.install!
    RecordingStudioTermsAndConditions::SoleLive.install!
    RecordingStudioTermsAndConditions::Published.install!
    restore_staff_access
  end

  def restore_staff_access
    return if @hooks.registered?(:after_record)

    staff = RecordingStudioTermsAndConditions::LibraryStaffAccess
    staff.instance_variable_set(:@installed, nil)
    staff.install!
  end
end
