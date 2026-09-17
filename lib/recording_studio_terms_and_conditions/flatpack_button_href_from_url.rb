# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Recording Studio Admin passes Flatpack buttons `url:`. Flatpack only
  # navigates when `href:` is set, so those render as inert <button>s.
  module FlatpackButtonHrefFromUrl
    def initialize(*args, **kwargs)
      kwargs[:href] ||= kwargs.delete(:url)
      super
    end
  end
end
