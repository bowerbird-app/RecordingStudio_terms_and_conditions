# frozen_string_literal: true

require "test_helper"
require "recording_studio_admin"

class ApiAccessTest < Minitest::Test
  def test_admin_root_uses_access_recording_resolver
    source = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/api/access.rb", __dir__))
    initializer = File.read(File.expand_path("dummy/config/initializers/recording_studio_admin.rb", __dir__))
    accessible = File.read(File.expand_path("dummy/config/initializers/recording_studio_accessible.rb", __dir__))

    assert_includes source, "access_recording_resolver"
    refute_includes source, "site_admin_recording_resolver"
    assert_includes initializer, "access_recording_resolver"
    assert_includes initializer, "RecordingStudioAccessible.admin_root"
    assert_includes accessible, "admin_root_resolver"
    assert_includes accessible, "Recording.kept"
    refute_includes initializer, "site_admin_recording_resolver"
    refute_includes accessible, "site_admin_recording_resolver"
    refute_includes initializer, "kept_sql"
    refute_includes accessible, "kept_sql"
  end

  def test_access_resolver_returns_the_admin_root
    access_recording = Object.new
    seen_context = nil

    with_access_resolver(lambda { |context|
      seen_context = context
      access_recording
    }) do
      assert_same access_recording, admin_root_recording
    end

    assert_nil seen_context.controller
  end

  def test_resolver_raising_denies_view_without_raising
    with_access_resolver(->(_context) { raise NoMethodError, "controller" }) do
      assert_equal false, can_view?(view_context(Object.new))
    end
  end

  def test_resolver_returning_nil_denies_view
    with_access_resolver(->(_context) {}) do
      assert_equal false, can_view?(view_context(Object.new))
    end
  end

  private

  def admin_root_recording
    RecordingStudioTermsAndConditions::Api::Access.admin_root_recording
  end

  def can_view?(context)
    RecordingStudioTermsAndConditions::Api::Access.can_view?(context)
  end

  def view_context(actor)
    grant = Struct.new(:actor).new(actor)
    Struct.new(:access_grant).new(grant)
  end

  def with_access_resolver(access)
    config = RecordingStudioAdmin.configuration
    original_access = config.access_recording_resolver
    config.access_recording_resolver = access
    yield
  ensure
    config.access_recording_resolver = original_access
  end
end
