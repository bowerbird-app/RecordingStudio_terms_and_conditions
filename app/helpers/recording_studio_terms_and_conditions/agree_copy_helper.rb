# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module AgreeCopyHelper
    TERMS_UPDATED_PAGE_TITLE = "We have updated our terms and conditions."
    PRIVACY_UPDATED_PAGE_TITLE = "We have updated our privacy policy."
    BOTH_UPDATED_PAGE_TITLE = "We have updated our terms and conditions and privacy policy."

    def terms_agree_heading(terms)
      terms&.title.presence || "Terms and Conditions"
    end

    def terms_accept_page_title(terms = nil, reaccepting: false, pending: nil) # rubocop:disable Lint/UnusedMethodArgument
      documents = accept_page_title_documents(terms, pending)
      has_terms = accept_page_has_terms?(documents)
      has_privacy = accept_page_has_privacy?(documents)

      if has_terms && has_privacy
        BOTH_UPDATED_PAGE_TITLE
      elsif has_privacy
        PRIVACY_UPDATED_PAGE_TITLE
      else
        TERMS_UPDATED_PAGE_TITLE
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
  end
end
