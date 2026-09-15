# frozen_string_literal: true

class CreateRecordingStudioTermsAndConditionsTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_terms_and_conditions_terms, id: :uuid do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.string :kind, null: false, default: "terms"
      t.datetime :created_at, null: false
      t.index :kind, name: "index_rstac_terms_on_kind"
    end
  end
end
