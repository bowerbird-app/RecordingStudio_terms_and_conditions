# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Narrows the who-agreed list. The host supplies actor_name_search.
  module ActorSearch
    module_function

    def apply(relation, term)
      query = term.to_s.strip
      search = RecordingStudioTermsAndConditions.configuration.actor_name_search
      return relation if query.empty? || search.nil?

      search.call(relation, query)
    end
  end
end
