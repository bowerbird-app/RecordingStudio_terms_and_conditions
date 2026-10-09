# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioTermsAndConditions
  module Metrics
    RESOURCE = :terms_acceptances
    API = :operations
    EXPOSE = { api: [API] }.freeze
    AUTHORIZE = ->(context) { RecordingStudioTermsAndConditions::Api::Access.can_view?(context) }

    module_function

    def register!
      RecordingStudioMetrics.register(
        RESOURCE,
        model: Acceptance,
        blast_radius: :site,
        api_authorize: AUTHORIZE
      ) { RecordingStudioTermsAndConditions::Metrics.define_acceptances(self) }
    end

    def define_acceptances(dsl)
      dsl.count :total, title: "Terms acceptances", expose: EXPOSE
      dsl.timeseries :over_time, title: "Acceptances over time", field: :accepted_at, expose: EXPOSE
      dsl.breakdown :by_version, title: "Acceptances by version", field: :terms_recording_id, expose: EXPOSE
    end
  end
end
