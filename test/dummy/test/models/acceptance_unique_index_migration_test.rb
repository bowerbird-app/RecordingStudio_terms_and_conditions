# frozen_string_literal: true

require "test_helper"

class AcceptanceUniqueIndexMigrationTest < ActiveSupport::TestCase
  INDEX_NAME = "index_rstac_acceptances_on_actor_and_version"
  TABLE = :recording_studio_terms_and_conditions_acceptances

  test "unique actor+version migration succeeds when that index was never created" do
    connection = ActiveRecord::Base.connection
    connection.remove_index(TABLE, name: INDEX_NAME, if_exists: true)
    refute connection.indexes(TABLE).any? { |index| index.name == INDEX_NAME }

    unique_migration.migrate(:up)

    unique = connection.indexes(TABLE).find { |index| index.name == INDEX_NAME }
    assert unique.unique
    assert_equal %w[actor_type actor_id terms_recording_id terms_id], unique.columns
  end

  test "unique actor+version migration replaces a non-unique index of the same name" do
    connection = ActiveRecord::Base.connection
    connection.remove_index(TABLE, name: INDEX_NAME, if_exists: true)
    connection.add_index(
      TABLE,
      %i[actor_type actor_id terms_recording_id terms_id],
      name: INDEX_NAME
    )
    refute connection.indexes(TABLE).find { |index| index.name == INDEX_NAME }.unique

    unique_migration.migrate(:up)

    unique = connection.indexes(TABLE).find { |index| index.name == INDEX_NAME }
    assert unique.unique
  end

  private

  def unique_migration
    require Rails.root.join(
      "db/migrate/20260915010002_make_recording_studio_terms_and_conditions_acceptances_unique_per_actor_and_version"
    ).to_s
    MakeRecordingStudioTermsAndConditionsAcceptancesUniquePerActorAndVersion.new
  end
end
