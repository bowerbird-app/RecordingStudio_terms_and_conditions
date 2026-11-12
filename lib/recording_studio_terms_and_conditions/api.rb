# frozen_string_literal: true

require_relative "api/actor_root"
require_relative "api/terms_payload"
require_relative "api/accept_pending"
require_relative "api/pending_published_list"
require_relative "api/current_published_for"
require_relative "api/accepted"

module RecordingStudioTermsAndConditions
  module Api
    ACTION_VERSION = "1.0.0"
    KIND_DESCRIPTION = "Terms kind: terms_and_condition or privacy_policy. Defaults to terms_and_condition."
    ACTIONS = {
      accept_pending: {
        http_verb: :post,
        handler: AcceptPending,
        title: "Terms - Accept",
        summary: "Accept pending Terms",
        description: "Accept every live Terms document the access grant's actor still needs in this workspace. " \
                     "A second call returns the same receipts."
      }.freeze,
      pending_published_list: {
        http_verb: :get,
        handler: PendingPublishedList,
        title: "Terms - Pending published list",
        summary: "List pending Terms",
        description: "Live Terms documents in this workspace the access grant's actor has not accepted yet."
      }.freeze,
      current_published_for: {
        http_verb: :get,
        handler: CurrentPublishedFor,
        title: "Terms - Current published",
        summary: "Show current published Terms",
        description: "The live Terms document for a kind in this workspace.",
        kind_field: true
      }.freeze,
      accepted: {
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
          return unless api_available?

          each_surface { |surface_name| register_surface(surface_name) }
          nil
        end

        private

        def api_available?
          defined?(RecordingStudioApi) &&
            RecordingStudioApi.respond_to?(:capability_action) &&
            RecordingStudioApi.respond_to?(:register_capability_action) &&
            defined?(RecordingStudioApi::ActionInputContract)
        end

        def each_surface
          if named_api_registration_supported?
            RecordingStudioApi.configuration.each_api { |definition| yield definition.name }
          else
            yield nil
          end
        end

        def named_api_registration_supported?
          RecordingStudioApi.respond_to?(:configuration) &&
            RecordingStudioApi.configuration.respond_to?(:each_api) &&
            accepts_api_keyword?(:capability_action) &&
            accepts_api_keyword?(:register_capability_action)
        end

        def accepts_api_keyword?(method_name)
          RecordingStudioApi.method(method_name).parameters.any? do |type, name|
            type == :keyrest || (name == :api && %i[key keyreq].include?(type))
          end
        end

        def register_surface(surface_name)
          ACTIONS.each_key { |action_name| register_action(surface_name, action_name) }
        end

        def register_action(surface_name, action_name)
          return if existing_action(surface_name, action_name)

          spec = ACTIONS.fetch(action_name)
          options = action_options(spec)
          if surface_name
            RecordingStudioApi.register_capability_action(action_name, api: surface_name, **options)
          else
            RecordingStudioApi.register_capability_action(action_name, **options)
          end
        end

        def existing_action(surface_name, action_name)
          if surface_name
            RecordingStudioApi.capability_action(action_name, api: surface_name)
          else
            RecordingStudioApi.capability_action(action_name)
          end
        end

        def fields_for(spec)
          return {} unless spec[:kind_field]

          {
            kind: {
              type: :string,
              required: false,
              allow_blank: true,
              enum: %w[terms_and_condition privacy_policy],
              description: KIND_DESCRIPTION
            }
          }
        end

        def action_options(spec)
          {
            **shared_action_options,
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
