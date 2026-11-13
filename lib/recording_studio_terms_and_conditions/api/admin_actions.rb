# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    module AdminActions
      module_function

      # rubocop:disable Layout/LineLength, Metrics/AbcSize, Metrics/MethodLength
      def definitions
        {
          terms_documents: entry(:get, Documents, "Terms - Documents", "List Terms documents", fields: {
                                   kind: string_field("Optional kind filter", required: false, enum: %w[terms_and_condition privacy_policy])
                                 }),
          terms_outline: entry(:get, OutlineAction, "Terms - Outline", "Read the numbered outline"),
          terms_section: entry(:get, SectionAction, "Terms - Section", "Read one section", fields: {
                                 section_id: string_field("Section id")
                               }),
          terms_clause: entry(:get, ClauseAction, "Terms - Clause", "Read one clause", fields: {
                                clause_id: string_field("Clause id")
                              }),
          terms_changes: entry(:get, Changes, "Terms - Changes", "Changes since the live release"),
          terms_preview: entry(:get, Preview, "Terms - Preview", "Full text the next release would publish", fields: {
                                 title: string_field("Optional title for the next release", required: false)
                               }),
          terms_add_section: entry(:post, AddSection, "Terms - Add section", "Add a section", role: :edit, fields: {
                                     heading: string_field("Section heading")
                                   }),
          terms_edit_section: entry(:post, EditSection, "Terms - Edit section", "Edit a section heading", role: :edit, fields: {
                                      section_id: string_field("Section id"),
                                      heading: string_field("Section heading")
                                    }),
          terms_move_section: entry(:post, MoveSection, "Terms - Move section", "Move a section", role: :edit, fields: {
                                      section_id: string_field("Section id"),
                                      to_index: index_field
                                    }),
          terms_remove_section: entry(:post, RemoveSection, "Terms - Remove section", "Remove a section", role: :edit, fields: {
                                        section_id: string_field("Section id")
                                      }),
          terms_add_clause: entry(:post, AddClause, "Terms - Add clause", "Add a clause", role: :edit, fields: {
                                    section_id: string_field("Section id"),
                                    body: string_field("Clause text")
                                  }),
          terms_edit_clause: entry(:post, EditClause, "Terms - Edit clause", "Edit a clause", role: :edit, fields: {
                                     clause_id: string_field("Clause id"),
                                     body: string_field("Clause text")
                                   }),
          terms_move_clause: entry(:post, MoveClause, "Terms - Move clause", "Move a clause", role: :edit, fields: {
                                     clause_id: string_field("Clause id"),
                                     to_index: index_field,
                                     section_id: string_field("Section id when the clause changes section",
                                                              required: false)
                                   }),
          terms_remove_clause: entry(:post, RemoveClause, "Terms - Remove clause", "Remove a clause", role: :edit, fields: {
                                       clause_id: string_field("Clause id")
                                     }),
          terms_release: entry(:post, Release, "Terms - Release", "Release the current outline", role: :edit, fields: {
                                 title: string_field("Title stored on the released version", required: false)
                               })
        }.freeze
      end
      # rubocop:enable Layout/LineLength, Metrics/AbcSize, Metrics/MethodLength

      def entry(verb, handler, title, summary, role: :view, fields: {}) # rubocop:disable Metrics/ParameterLists
        {
          http_verb: verb,
          handler: handler,
          title: title,
          summary: summary,
          description: summary,
          required_role: role,
          fields: fields
        }.freeze
      end

      def string_field(description, required: true, enum: nil)
        field = { type: :string, required: required, allow_blank: !required, description: description }
        field[:enum] = enum if enum
        field
      end

      def index_field
        { type: :integer, required: true, description: "Zero-based position among its siblings" }
      end
    end
  end
end
