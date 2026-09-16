# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module AgreeCopyHelper
    def terms_agree_heading(terms)
      terms&.title.presence || "Terms and Conditions"
    end

    def terms_reaccept_alert_title
      "Terms updated"
    end

    def terms_users_subtitle(_terms = nil)
      "People who ticked the box for these terms."
    end
  end
end
