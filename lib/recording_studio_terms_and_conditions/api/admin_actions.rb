# frozen_string_literal: true

require_relative "admin_action_fields"
require_relative "admin_action_specs"

module RecordingStudioTermsAndConditions
  module Api
    module AdminActions
      module_function

      NAMES = %i[
        terms_documents
        terms_create
        terms_update
        terms_outline
        terms_section
        terms_clause
        terms_changes
        terms_preview
        terms_add_section
        terms_edit_section
        terms_move_section
        terms_remove_section
        terms_add_clause
        terms_edit_clause
        terms_move_clause
        terms_remove_clause
        terms_release
      ].freeze

      def definitions
        NAMES.to_h { |name| [name, public_send(:"#{name}_action")] }.freeze
      end
    end
  end
end
