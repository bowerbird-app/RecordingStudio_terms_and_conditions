# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    module AdminActions # rubocop:disable Metrics/ModuleLength
      module_function

      # rubocop:disable Layout/LineLength, Metrics/AbcSize, Metrics/MethodLength
      def definitions
        {
          terms_documents: entry(:get, Documents, "Terms - Documents", "List Terms documents",
                                 description: documents_description,
                                 fields: {
                                   kind: string_field("Optional kind filter", required: false, enum: %w[terms_and_condition privacy_policy])
                                 }),
          terms_create: entry(:post, Create, "Terms - Create", "Create a Terms document",
                              role: :edit, include_terms_id: false, description: create_description, fields: create_fields),
          terms_update: entry(:post, Update, "Terms - Update", "Update a Terms document",
                              role: :edit, description: update_description, fields: update_fields),
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
                               }, description: release_description)
        }.freeze
      end
      # rubocop:enable Layout/LineLength, Metrics/AbcSize, Metrics/MethodLength

      def create_fields
        {
          title: string_field("Document title"),
          kind: string_field("terms_and_condition or privacy_policy", enum: %w[terms_and_condition privacy_policy]),
          body: string_field("Starting copy. Seeded into sections and clauses.")
        }
      end

      def update_fields
        {
          title: string_field("Document title"),
          body: string_field("Document body. Only when the document has no outline.", required: false)
        }
      end

      def documents_description
        "Lists Terms and Privacy Policy documents on the shared library. " \
          "Each document is one lineage. Pass kind to keep only that type. " \
          "Call this from AdminRoot."
      end

      def create_description
        "Creates a Terms or Privacy Policy document on the shared library and seeds its outline. " \
          "The document is the legal copy people agree to. One lineage per kind. " \
          "Refuses if that kind already exists. Pass title, kind, and body. " \
          "Edit sections and clauses, then release."
      end

      def update_description
        "Updates a Terms document with no outline. A rename of an outlined document is refused for now. " \
          "Pass terms_id of the document on the shared library. " \
          "A document with an outline is edited as sections and clauses, then released."
      end

      def release_description
        "Releases the current outline as the live version. People who already agreed must agree again. " \
          "Pass terms_id. Title is optional. The document must already exist, with sections and clauses ready."
      end

      def entry(verb, handler, title, summary, role: :view, fields: {}, description: nil, include_terms_id: true) # rubocop:disable Metrics/ParameterLists
        {
          http_verb: verb,
          handler: handler,
          title: title,
          summary: summary,
          description: description || summary,
          required_role: role,
          fields: with_terms_id(fields, include_terms_id: include_terms_id)
        }.freeze
      end

      def with_terms_id(fields, include_terms_id: true)
        return fields unless include_terms_id

        fields.merge(terms_id: string_field("Terms document id on the shared library.", required: false))
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
