# frozen_string_literal: true

require "pagy"
require "pagy/extras/overflow"

module RecordingStudioTermsAndConditions
  # Shared page size for engine tables. Matches Recording Studio Admin dummy tables
  # (`paginate per_page: 25`) and Flatpack infinite pagination.
  module TablePage
    SIZE = 25

    def paginate_table(scope)
      pagy(scope, limit: SIZE, overflow: :last_page)
    end
  end
end
