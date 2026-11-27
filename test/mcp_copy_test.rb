# frozen_string_literal: true

require "test_helper"
require "recording_studio_terms_and_conditions"

class McpCopyTest < Minitest::Test
  PUBLIC_TOOLS = %w[
    terms_pending_published_list
    terms_current_published_for
    terms_accepted
  ].freeze

  OPERATIONS_TOOLS = %w[
    terms_documents
    terms_create
    terms_update
    terms_outline
    terms_section
    terms_clause
    terms_changes
    terms_preview
    terms_add_section
    terms_edit_section
    terms_move_section
    terms_remove_section
    terms_add_clause
    terms_edit_clause
    terms_move_clause
    terms_remove_clause
    terms_release
  ].freeze

  def test_register_is_a_noop_without_recording_studio_mcp
    refute Object.const_defined?(:RecordingStudioMcp, false)
    assert_nil RecordingStudioTermsAndConditions::McpCopy.register!
  end

  def test_tool_names_split_public_and_operations
    assert_equal PUBLIC_TOOLS, RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public)
    assert_equal OPERATIONS_TOOLS, RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :operations)
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public), "terms_create"
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public), "terms_update"
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public), "terms_release"
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names, "terms_accept_pending"
    refute_includes RecordingStudioTermsAndConditions::McpCopy.tool_names, "terms_accept"
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
