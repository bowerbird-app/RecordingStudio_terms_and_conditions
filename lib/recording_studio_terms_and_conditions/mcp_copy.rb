# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  module McpCopy
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

    TYPE = "RecordingStudioTermsAndConditions::Terms"
    DOCUMENT =
      "A Terms document is the legal copy people agree to. One lineage per kind lives on the shared library. " \
      "Kinds are terms_and_condition and privacy_policy. Sections and clauses sit under that document. " \
      "Release makes a live version."

    module_function

    def register!
      return unless defined?(::RecordingStudioMcp)
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      tool_names.each { |name| register_tool(name) }
      nil
    end

    def tool_names(api: nil)
      case api&.to_sym
      when :public then PUBLIC_TOOLS
      when :operations then OPERATIONS_TOOLS
      else (PUBLIC_TOOLS + OPERATIONS_TOOLS).uniq
      end
    end

    def register_tool(name)
      spec = spec_for(name)
      ::RecordingStudioMcp.register_tool(
        name: name,
        action: name.to_sym,
        type: TYPE,
        title: spec.fetch(:title),
        description: [spec.fetch(:description), DOCUMENT].join(" ")
      )
    end

    def spec_for(name)
      key = name.to_sym
      Api::ACTIONS[key] || Api::AdminActions.definitions.fetch(key)
    end
  end
end
