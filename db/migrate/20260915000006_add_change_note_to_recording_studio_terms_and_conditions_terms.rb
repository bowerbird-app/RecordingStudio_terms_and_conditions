# frozen_string_literal: true

class AddChangeNoteToRecordingStudioTermsAndConditionsTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_terms_and_conditions_terms, :change_note, :text
  end
end
