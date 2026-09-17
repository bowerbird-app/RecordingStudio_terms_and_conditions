# frozen_string_literal: true

require "recording_studio"
require "recording_studio_publishable"
require "recording_studio_terms_and_conditions/version"
require "recording_studio_terms_and_conditions/sample_terms"
require "recording_studio_terms_and_conditions/configuration"
require "recording_studio_terms_and_conditions/body_digest"
require "recording_studio_terms_and_conditions/engine"
require "recording_studio_terms_and_conditions/terms_acceptance"
require "recording_studio_terms_and_conditions/table_page"
require "recording_studio_terms_and_conditions/gate"
require "recording_studio_terms_and_conditions/forces_acceptance"
require "recording_studio_terms_and_conditions/users_auth_redirect"
require "recording_studio_terms_and_conditions/acceptance_gate_installer"
require "recording_studio_terms_and_conditions/admin_widget_card"
require "recording_studio_terms_and_conditions/flatpack_button_href_from_url"
require "recording_studio_terms_and_conditions/admin" if defined?(RecordingStudioAdmin)
require "recording_studio_terms_and_conditions/capabilities/example"

module RecordingStudioTermsAndConditions
  class NotLive < StandardError; end

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

    def pending_published_for(actor, root)
      TermsAcceptance.pending_published_for(actor, root)
    end

    def pending_published_list(actor, root)
      TermsAcceptance.pending_published_list(actor, root)
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

    def reaccepting?(actor, root)
      TermsAcceptance.reaccepting?(actor, root)
    end
  end
end
