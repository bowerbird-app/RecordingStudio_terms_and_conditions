# frozen_string_literal: true

class AddProvenanceToRecordingStudioTermsAndConditionsAcceptances < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_terms_and_conditions_acceptances, :provenance, :jsonb, null: false, default: {}
    add_index :recording_studio_terms_and_conditions_acceptances,
              %i[actor_type actor_id terms_recording_id terms_id],
              name: "index_rstac_acceptances_on_actor_and_version"
  end
end
