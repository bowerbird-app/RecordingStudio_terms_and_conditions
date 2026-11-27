# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    module AdminActions
      module_function

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
        "Updates a Terms document's title. Body only when the document has no outline. " \
          "Pass terms_id of the document on the shared library. " \
          "A document with an outline is edited as sections and clauses, then released."
      end

      def release_description
        "Releases the current outline as the live version. People who already agreed must agree again. " \
          "Pass terms_id. Title is optional. The document must already exist, with sections and clauses ready."
      end

      def entry(verb, handler, title, summary, **options)
        {
          http_verb: verb,
          handler: handler,
          title: title,
          summary: summary,
          description: options[:description] || summary,
          required_role: options.fetch(:role, :view),
          fields: with_terms_id(options.fetch(:fields, {}), include_terms_id: options.fetch(:include_terms_id, true))
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
