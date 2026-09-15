# frozen_string_literal: true

require "recording_studio"
require "recording_studio_publishable"
require "recording_studio_terms_and_conditions/version"
require "recording_studio_terms_and_conditions/sample_terms"
require "recording_studio_terms_and_conditions/configuration"
require "recording_studio_terms_and_conditions/body_digest"
require "recording_studio_terms_and_conditions/engine"
require "recording_studio_terms_and_conditions/terms_acceptance"
require "recording_studio_terms_and_conditions/kind_uniqueness"
require "recording_studio_terms_and_conditions/kind_coverage"
require "recording_studio_terms_and_conditions/table_page"
require "recording_studio_terms_and_conditions/gate"
require "recording_studio_terms_and_conditions/forces_acceptance"
require "recording_studio_terms_and_conditions/users_auth_redirect"
require "recording_studio_terms_and_conditions/acceptance_gate_installer"
require "recording_studio_terms_and_conditions/admin_widget_card"
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

    def current_published_for(root, kind: Terms::DEFAULT_KIND)
      TermsAcceptance.current_published_for(root, kind: kind)
    end

    def current_published_by_kind(root)
      TermsAcceptance.current_published_by_kind(root)
    end

    def pending_published_for(actor, root, required_kinds: nil)
      TermsAcceptance.pending_published_for(actor, root, required_kinds: required_kinds)
    end

    def pending_published_list(actor, root, required_kinds: nil)
      TermsAcceptance.pending_published_list(actor, root, required_kinds: required_kinds)
    end

    def accepted?(actor, root, kind: Terms::DEFAULT_KIND)
      TermsAcceptance.accepted?(actor, root, kind: kind)
    end

    def requires_acceptance?(actor, root, kind: nil, required_kinds: nil)
      TermsAcceptance.requires_acceptance?(actor, root, kind: kind, required_kinds: required_kinds)
    end

    def accept!(actor, version, provenance = {})
      TermsAcceptance.accept!(actor, version, provenance)
    end

    def reaccepting?(actor, root, kind: nil, required_kinds: nil)
      TermsAcceptance.reaccepting?(actor, root, kind: kind, required_kinds: required_kinds)
    end
  end
end
