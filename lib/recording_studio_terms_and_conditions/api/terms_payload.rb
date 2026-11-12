# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    module TermsPayload
      module_function

      def terms_hash(terms)
        return if terms.blank?

        {
          id: terms.id.to_s,
          kind: terms.kind,
          title: terms.title,
          body: terms.body
        }
      end

      def kind_from(params)
        value = params[:kind]
        return RecordingStudioTermsAndConditions::Terms::DEFAULT_KIND if value.blank?

        RecordingStudioTermsAndConditions::Terms.normalize_kind(value)
      end
    end
  end
end
