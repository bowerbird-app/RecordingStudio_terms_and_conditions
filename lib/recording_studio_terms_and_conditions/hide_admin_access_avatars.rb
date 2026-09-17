# frozen_string_literal: true

require "active_support/core_ext/string/output_safety"

module RecordingStudioTermsAndConditions
  # Recording Studio Admin puts Accessible avatars (or "+ Access") on the
  # section hub. Terms screens stay on PageNav plus the hub actions.
  module HideAdminAccessAvatars
    def recording_studio_accessible_avatars(*)
      "".html_safe
    end
  end
end
