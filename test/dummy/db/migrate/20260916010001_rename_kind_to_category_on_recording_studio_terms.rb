# frozen_string_literal: true

class RenameKindToCategoryOnRecordingStudioTerms < ActiveRecord::Migration[8.1]
  def up
    table = :recording_studio_terms_and_conditions_terms
    return unless column_exists?(table, :kind)
    return if column_exists?(table, :category)

    rename_column table, :kind, :category
    return unless index_name_exists?(table, "index_rstac_terms_on_kind")

    rename_index table, "index_rstac_terms_on_kind", "index_rstac_terms_on_category"
  end

  def down
    table = :recording_studio_terms_and_conditions_terms
    return unless column_exists?(table, :category)
    return if column_exists?(table, :kind)

    rename_column table, :category, :kind
    return unless index_name_exists?(table, "index_rstac_terms_on_category")

    rename_index table, "index_rstac_terms_on_category", "index_rstac_terms_on_kind"
  end
end
