# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module TablePaginationHelper
    def terms_table_pagination(pagy)
      return if pagy.blank?

      render(
        FlatPack::Pagination::Component.new(
          pagy: pagy,
          mode: :infinite,
          class: "mt-4"
        )
      )
    end
  end
end
