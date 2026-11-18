# frozen_string_literal: true

RecordingStudioTermsAndConditions.configure do |config|
  # config.mount_path = "/recording_studio_terms_and_conditions"

  config.app_name = "Terms Dummy"
  config.gate_exempt_controllers += %w[
    recording_studio_user/auth
    recording_studio_user/omniauth
  ]
  config.actor_name_search = lambda do |relation, term|
    like = "%#{RecordingStudioTermsAndConditions::Acceptance.sanitize_sql_like(term)}%"
    acceptances = RecordingStudioTermsAndConditions::Acceptance.table_name
    relation.joins(
      "LEFT JOIN users ON users.id = #{acceptances}.actor_id " \
      "AND #{acceptances}.actor_type = 'User' " \
      "LEFT JOIN recording_studio_user_profiles profiles ON profiles.user_id = users.id"
    ).where(
      "users.email ILIKE :term OR profiles.first_name ILIKE :term OR " \
      "profiles.last_name ILIKE :term OR " \
      "(profiles.first_name || ' ' || profiles.last_name) ILIKE :term",
      term: like
    )
  end
end
