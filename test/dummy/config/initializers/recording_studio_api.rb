# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudio.enable_capability(:api_access_point, on: "Workspace")

RecordingStudioApi.configure do |config|
  config.documentation_enabled = true
  config.documentation_access = :public
  config.openapi_title = "Terms dummy API"
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_management_authorization_required = false
  config.api_request_logging_enabled = false

  config.api :operations do |api|
    api.openapi_title = "Operations API"
    api.api_versions = %w[v1]
    api.default_access = :read_only
    api.api_management_authorization_required = false
    api.documentation_enabled = false
    api.api_request_logging_enabled = false
  end
end

RecordingStudioApi.register_default_resource_actions!(api: :operations)
RecordingStudioApi.register_default_capability_actions!(api: :operations)

RecordingStudioApi.register_recordable_type_api(
  "Workspace",
  operations: %i[index show],
  serializer: ->(workspace, **) { { name: workspace.name } },
  output_keys: %i[name],
  capability_actions: %i[terms_pending_published_list terms_current_published_for terms_accepted]
)
