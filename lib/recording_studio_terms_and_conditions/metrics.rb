# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioTermsAndConditions
  module Metrics
    RESOURCE = :terms_acceptances
    API = :operations
    EXPOSE = { api: [API] }.freeze
    KIND_GROUPS = %i[kind].freeze
    OVER_TIME_DESCRIPTION = "Acceptance receipts by accepted_at. Group by kind (terms_and_condition or " \
                            "privacy_policy) of the accepted Terms snapshot."
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
      dsl.timeseries :over_time, title: "Acceptances over time", description: OVER_TIME_DESCRIPTION,
                                 unit: "count", field: :accepted_at, group_by: KIND_GROUPS,
                                 scope: RecordingStudioTermsAndConditions::Metrics.method(:with_kind), expose: EXPOSE
      dsl.breakdown :by_version, title: "Acceptances by version", field: :terms_recording_id, expose: EXPOSE
    end

    # Acceptances with the accepted snapshot's Terms#kind exposed as a kind column, so the stock
    # timeseries calculator can group_by it. Kind lives on the Terms snapshot (terms_id), not on
    # the receipt.
    def with_kind(relation)
      table = Acceptance.table_name
      terms = Terms.table_name
      sql = relation.unscope(:select)
                    .joins("INNER JOIN #{terms} accepted_terms ON accepted_terms.id = #{table}.terms_id")
                    .select("#{table}.*", "accepted_terms.kind AS kind")
      Acceptance.unscoped.from("(#{sql.to_sql}) #{table}")
    end
  end
end
