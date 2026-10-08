# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module AgreeCopyHelper
    def terms_agree_heading(terms)
      terms&.title.presence || Copy.t("accept.heading_fallback")
    end

    def terms_accept_page_title(terms = nil, reaccepting: false, pending: nil)
      documents = accept_page_title_documents(terms, pending)
      has_terms = accept_page_has_terms?(documents)
      has_privacy = accept_page_has_privacy?(documents)

      if reaccepting
        updated_accept_page_title(has_terms:, has_privacy:)
      else
        first_accept_page_title(has_terms:, has_privacy:)
      end
    end

    def terms_users_subtitle(_terms = nil)
      "People who ticked the box for these terms."
    end

    def terms_document(documents)
      Array(documents).find { |doc| doc.try(:terms_and_condition?) } ||
        Array(documents).find { |doc| !doc.try(:privacy_policy?) }
    end

    def privacy_document(documents)
      Array(documents).find { |doc| doc.try(:privacy_policy?) }
    end

    def terms_copy(key, **)
      Copy.t(key, **)
    end

    private

    def accept_page_title_documents(terms, pending)
      documents = Array(pending).compact
      return documents if documents.any?

      Array(terms).compact
    end

    def accept_page_has_terms?(documents)
      documents.any? { |doc| doc.try(:terms_and_condition?) } ||
        documents.any? { |doc| !doc.try(:privacy_policy?) }
    end

    def accept_page_has_privacy?(documents)
      documents.any? { |doc| doc.try(:privacy_policy?) }
    end

    def updated_accept_page_title(has_terms:, has_privacy:)
      if has_terms && has_privacy
        Copy.t("accept.updated.both")
      elsif has_privacy
        Copy.t("accept.updated.privacy")
      else
        Copy.t("accept.updated.terms")
      end
    end

    def first_accept_page_title(has_terms:, has_privacy:)
      if has_terms && has_privacy
        Copy.t("accept.first.both")
      elsif has_privacy
        Copy.t("accept.first.privacy")
      else
        Copy.t("accept.first.terms")
      end
    end
  end
end
