# frozen_string_literal: true

require_relative "api/access"
require_relative "api/actor_root"
require_relative "api/terms_payload"
require_relative "api/pending_published_list"
require_relative "api/current_published_for"
require_relative "api/accepted"
require_relative "api/admin_actions"
require_relative "api/admin_handlers"

module RecordingStudioTermsAndConditions
  module Api
    ACTION_VERSION = "1.0.0"
    KIND_DESCRIPTION = "Terms kind: terms_and_condition or privacy_policy. Defaults to terms_and_condition."
    KIND_FIELD = {
      kind: {
        type: :string,
        required: false,
        allow_blank: true,
        enum: %w[terms_and_condition privacy_policy],
        description: KIND_DESCRIPTION
      }
    }.freeze
    ACTIONS = {
      terms_pending_published_list: {
        http_verb: :get,
        handler: PendingPublishedList,
        title: "Terms - Pending published list",
        summary: "List pending Terms",
        description: "Live Terms documents in this workspace the access grant's actor has not accepted yet."
      }.freeze,
      terms_current_published_for: {
        http_verb: :get,
        handler: CurrentPublishedFor,
        title: "Terms - Current published",
        summary: "Show current published Terms",
        description: "The live Terms document for a kind in this workspace.",
        kind_field: true
      }.freeze,
      terms_accepted: {
        http_verb: :get,
        handler: Accepted,
        title: "Terms - Accepted",
        summary: "Check Terms acceptance",
        description: "Whether the access grant's actor has accepted the live Terms document for a kind.",
        kind_field: true
      }.freeze
    }.freeze

    def self.register_capability_action!
      Registration.register!
    end

    module Registration
      class << self
        def register!
          return unless defined?(::RecordingStudioApi)

          RecordingStudioApi.configuration.each_api { |definition| register_surface(definition.name) }
          nil
        end

        private

        def register_surface(surface_name)
          action_map.each_key { |action_name| register_action(surface_name, action_name) }
        end

        def action_map
          ACTIONS.merge(AdminActions.definitions)
        end

        def register_action(surface_name, action_name)
          existing_action(surface_name, action_name)
          spec = action_map.fetch(action_name)
          RecordingStudioApi.register_capability_action(action_name, api: surface_name, **action_options(spec))
        end

        def existing_action(surface_name, action_name)
          found = RecordingStudioApi.capability_action(action_name, api: surface_name)
          return unless found

          raise ArgumentError, "#{action_name} is already registered on API #{surface_name}"
        end

        def fields_for(spec)
          return spec[:fields] if spec[:fields]
          return {} unless spec[:kind_field]

          KIND_FIELD
        end

        def action_options(spec)
          {
            **shared_action_options,
            required_role: spec.fetch(:required_role, :view),
            http_verb: spec.fetch(:http_verb),
            handler: spec.fetch(:handler),
            input_contract: { reject_unknown: false, fields: fields_for(spec) },
            openapi: openapi_for(spec)
          }
        end

        def shared_action_options
          {
            capability: :terms_and_conditions,
            version: ACTION_VERSION,
            scope: :member,
            required_role: :view,
            serializer: ->(result) { result }
          }
        end

        def openapi_for(spec)
          {
            title: spec.fetch(:title),
            summary: spec.fetch(:summary),
            description: spec.fetch(:description)
          }
        end
      end
    end
  end
end
