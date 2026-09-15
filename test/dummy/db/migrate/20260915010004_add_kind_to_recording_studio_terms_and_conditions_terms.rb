# frozen_string_literal: true

class AddKindToRecordingStudioTermsAndConditionsTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_terms_and_conditions_terms, :kind, :string,
               null: false, default: "terms", if_not_exists: true
    add_index :recording_studio_terms_and_conditions_terms, :kind,
              name: "index_rstac_terms_on_kind",
              if_not_exists: true
  end
end
