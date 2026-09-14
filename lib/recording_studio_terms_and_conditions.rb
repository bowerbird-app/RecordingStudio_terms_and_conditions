# frozen_string_literal: true

require "recording_studio"
require "recording_studio_publishable"
require "recording_studio_terms_and_conditions/version"
require "recording_studio_terms_and_conditions/engine"
require "recording_studio_terms_and_conditions/configuration"
require "recording_studio_terms_and_conditions/terms_acceptance"
require "recording_studio_terms_and_conditions/admin" if defined?(RecordingStudioAdmin)
require "recording_studio_terms_and_conditions/capabilities/example"

module RecordingStudioTermsAndConditions
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def current_published_for(root)
      TermsAcceptance.current_published_for(root)
    end

    def accepted?(actor, root)
      TermsAcceptance.accepted?(actor, root)
    end

    def requires_acceptance?(actor, root)
      TermsAcceptance.requires_acceptance?(actor, root)
    end

    def accept!(actor, version, provenance = {})
      TermsAcceptance.accept!(actor, version, provenance)
    end
  end
end
