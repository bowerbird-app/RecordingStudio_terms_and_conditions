# frozen_string_literal: true

require "test_helper"
require "recording_studio_admin"

class ApiAccessTest < Minitest::Test
  def test_site_resolver_is_preferred_when_set
    site_recording = Object.new
    access_called = false
    seen_context = nil

    with_resolvers(
      site: lambda { |context|
        seen_context = context
        site_recording
      },
      access: lambda { |_context|
        access_called = true
        Object.new
      }
    ) do
      assert_same site_recording, admin_root_recording
    end

    refute access_called
    assert_nil seen_context.controller
  end

  def test_falls_back_to_access_resolver_when_site_resolver_is_unset
    access_recording = Object.new

    with_resolvers(site: nil, access: ->(_context) { access_recording }) do
      assert_same access_recording, admin_root_recording
    end
  end

  def test_resolver_raising_denies_view_without_raising
    access_called = false

    with_resolvers(
      site: ->(_context) { raise NoMethodError, "controller" },
      access: lambda { |_context|
        access_called = true
        Object.new
      }
    ) do
      assert_equal false, can_view?(view_context(Object.new))
    end

    refute access_called
  end

  def test_resolver_returning_nil_denies_view
    access_called = false

    with_resolvers(
      site: ->(_context) {},
      access: lambda { |_context|
        access_called = true
        Object.new
      }
    ) do
      assert_equal false, can_view?(view_context(Object.new))
    end

    refute access_called
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

  def with_resolvers(site:, access:)
    config = RecordingStudioAdmin.configuration
    original_site = config.site_admin_recording_resolver
    original_access = config.access_recording_resolver
    config.site_admin_recording_resolver = site
    config.access_recording_resolver = access
    yield
  ensure
    config.site_admin_recording_resolver = original_site
    config.access_recording_resolver = original_access
  end
end
