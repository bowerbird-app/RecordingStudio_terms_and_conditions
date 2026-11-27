# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    module AdminActions
      module_function

      def terms_documents_action
        entry(:get, Documents, "Terms - Documents", "List Terms documents",
              description: documents_description,
              fields: {
                kind: string_field(
                  "Optional kind filter",
                  required: false,
                  enum: %w[terms_and_condition privacy_policy]
                )
              })
      end

      def terms_create_action
        entry(:post, Create, "Terms - Create", "Create a Terms document",
              role: :edit, include_terms_id: false,
              description: create_description, fields: create_fields)
      end

      def terms_update_action
        entry(:post, Update, "Terms - Update", "Update a Terms document",
              role: :edit, description: update_description, fields: update_fields)
      end

      def terms_outline_action
        entry(:get, OutlineAction, "Terms - Outline", "Read the numbered outline",
              description: "Reads the numbered outline of a Terms document. " \
                           "Pass terms_id of the document on the shared library.")
      end

      def terms_section_action
        entry(:get, SectionAction, "Terms - Section", "Read one section",
              fields: { section_id: string_field("Section id") })
      end

      def terms_clause_action
        entry(:get, ClauseAction, "Terms - Clause", "Read one clause",
              fields: { clause_id: string_field("Clause id") })
      end

      def terms_changes_action
        entry(:get, Changes, "Terms - Changes", "Changes since the live release")
      end

      def terms_preview_action
        entry(:get, Preview, "Terms - Preview", "Full text the next release would publish",
              fields: { title: string_field("Optional title for the next release", required: false) })
      end

      def terms_add_section_action
        entry(:post, AddSection, "Terms - Add section", "Add a section",
              role: :edit, fields: { heading: string_field("Section heading") })
      end

      def terms_edit_section_action
        entry(:post, EditSection, "Terms - Edit section", "Edit a section heading",
              role: :edit,
              fields: {
                section_id: string_field("Section id"),
                heading: string_field("Section heading")
              })
      end

      def terms_move_section_action
        entry(:post, MoveSection, "Terms - Move section", "Move a section",
              role: :edit,
              fields: { section_id: string_field("Section id"), to_index: index_field })
      end

      def terms_remove_section_action
        entry(:post, RemoveSection, "Terms - Remove section", "Remove a section",
              role: :edit, fields: { section_id: string_field("Section id") })
      end

      def terms_add_clause_action
        entry(:post, AddClause, "Terms - Add clause", "Add a clause",
              role: :edit,
              fields: { section_id: string_field("Section id"), body: string_field("Clause text") })
      end

      def terms_edit_clause_action
        entry(:post, EditClause, "Terms - Edit clause", "Edit a clause",
              role: :edit,
              fields: { clause_id: string_field("Clause id"), body: string_field("Clause text") })
      end

      def terms_move_clause_action
        entry(:post, MoveClause, "Terms - Move clause", "Move a clause",
              role: :edit,
              fields: {
                clause_id: string_field("Clause id"),
                to_index: index_field,
                section_id: string_field("Section id when the clause changes section", required: false)
              })
      end

      def terms_remove_clause_action
        entry(:post, RemoveClause, "Terms - Remove clause", "Remove a clause",
              role: :edit, fields: { clause_id: string_field("Clause id") })
      end

      def terms_release_action
        entry(:post, Release, "Terms - Release", "Release the current outline",
              role: :edit,
              fields: { title: string_field("Title stored on the released version", required: false) },
              description: release_description)
      end
    end
  end
end
