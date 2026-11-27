# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  module McpCopy
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
      when :public then public_tools
      when :operations then operations_tools
      else (public_tools + operations_tools).uniq
      end
    end

    def public_tools
      Api::ACTIONS.keys.map(&:to_s)
    end

    def operations_tools
      Api::AdminActions.definitions.keys.map(&:to_s)
    end

    def register_tool(name)
      spec = spec_for(name)
      ::RecordingStudioMcp.register_tool(
        name: name,
        action: name.to_sym,
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
