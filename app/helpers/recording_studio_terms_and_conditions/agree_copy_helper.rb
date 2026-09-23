# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module AgreeCopyHelper
    TERMS_UPDATED_PAGE_TITLE = "We have updated our terms and conditions."

    def terms_agree_heading(terms)
      terms&.title.presence || "Terms and Conditions"
    end

    def terms_accept_page_title(*_args, **_kwargs)
      TERMS_UPDATED_PAGE_TITLE
    end

    def terms_users_subtitle(_terms = nil)
      "People who ticked the box for these terms."
    end
  end
end
