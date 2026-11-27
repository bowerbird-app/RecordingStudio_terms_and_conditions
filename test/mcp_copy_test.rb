# frozen_string_literal: true

require "test_helper"
require "recording_studio_terms_and_conditions"

class McpCopyTest < Minitest::Test
  def test_register_is_a_noop_without_recording_studio_mcp
    refute Object.const_defined?(:RecordingStudioMcp, false)
    assert_nil RecordingStudioTermsAndConditions::McpCopy.register!
  end

  def test_tool_names_split_public_and_operations
    public_tools = RecordingStudioTermsAndConditions::Api::ACTIONS.keys.map(&:to_s)
    operations_tools = RecordingStudioTermsAndConditions::Api::AdminActions.definitions.keys.map(&:to_s)

    assert_equal public_tools, RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public)
    assert_equal operations_tools, RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :operations)
    operations_tools.each do |name|
      refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public), name
    end
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names, "terms_accept_pending"
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names, "terms_accept"
    assert RecordingStudioTermsAndConditions::Api::AdminActions.create_fields[:body][:required]
  end

  def test_register_tool_omits_type_so_mcp_adds_the_enabled_type_enum
    calls = []
    mcp = Module.new
    mcp.define_singleton_method(:register_tool) { |**kwargs| calls << kwargs }
    Object.const_set(:RecordingStudioMcp, mcp)

    RecordingStudioTermsAndConditions::McpCopy.register!

    refute_empty calls
    names = calls.map { |kwargs| kwargs[:name] }
    RecordingStudioTermsAndConditions::McpCopy.tool_names.each do |name|
      assert_includes names, name
    end
    blurb = RecordingStudioTermsAndConditions::McpCopy::DOCUMENT
    calls.each do |kwargs|
      refute kwargs.key?(:type), kwargs.inspect
      assert_equal kwargs[:name].to_sym, kwargs[:action]
      description = kwargs[:description]
      assert description.end_with?(blurb), kwargs[:name]
      summary = description.delete_suffix(" #{blurb}")
      assert_match(/[.!?]\z/, summary, kwargs[:name])
    end
  ensure
    Object.send(:remove_const, :RecordingStudioMcp) if Object.const_defined?(:RecordingStudioMcp, false)
  end

  def test_mcp_copy_names_the_thing_and_omits_access_wording
    copy = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/mcp_copy.rb", __dir__))
    actions = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/api/admin_actions.rb", __dir__))
    public_actions = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/api.rb", __dir__))
    [copy, actions, public_actions].each do |text|
      refute_match(/\bAccess(ible)?\b/, text)
      refute_match(/\b(view|edit|admin) grant\b/i, text)
      refute_includes text, "operations token"
      refute_includes text, "public token"
    end
    assert_includes copy, "legal copy"
    assert_includes copy, "register_tool"
  end
end
