# frozen_string_literal: true

require "erb"
require "i18n"

module RecordingStudioTermsAndConditions
  module Copy
    PREFIX = "recording_studio.terms_and_conditions"
    UNSET = Object.new.freeze

    module_function

    def t(key, **options)
      full_key = "#{PREFIX}.#{key}"
      return I18n.t(full_key, **options) unless key.to_s.end_with?("_html")

      interpolate_html(key, **options)
    end

    def interpolate_html(key, **options)
      escaped = options.transform_values do |value|
        next value unless value.is_a?(String)
        next value if value.html_safe?

        ERB::Util.html_escape(value)
      end
      I18n.t("#{PREFIX}.#{key}", **escaped).to_s.html_safe
    end

    def provided?(value)
      !value.equal?(UNSET)
    end

    def value(override, key, **)
      provided?(override) ? override : t(key, **)
    end

    # Host config or helper text that still matches the English default follows
    # the locale. A different string (including blank after presence) wins.
    def defaulted(value, default, key, **)
      return t(key, **) if value.nil? || value == default

      value
    end
  end
end
