# frozen_string_literal: true

require "recording_studio"
require "recording_studio_publishable"
require "recording_studio_terms_and_conditions/version"
require "recording_studio_terms_and_conditions/engine"
require "recording_studio_terms_and_conditions/configuration"
require "recording_studio_terms_and_conditions/capabilities/example"

module RecordingStudioTermsAndConditions
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
