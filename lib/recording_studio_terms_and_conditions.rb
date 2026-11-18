# frozen_string_literal: true

require "recording_studio"
require "recording_studio_publishable"
require "recording_studio_terms_and_conditions/version"
require "recording_studio_terms_and_conditions/copy"
require "recording_studio_terms_and_conditions/sample_terms"
require "recording_studio_terms_and_conditions/configuration"
require "recording_studio_terms_and_conditions/body_digest"
require "recording_studio_terms_and_conditions/engine"
require "recording_studio_terms_and_conditions/library_root"
require "recording_studio_terms_and_conditions/library_staff_access"
require "recording_studio_terms_and_conditions/library_moves"
require "recording_studio_terms_and_conditions/terms_acceptance"
require "recording_studio_terms_and_conditions/terms_write"
require "recording_studio_terms_and_conditions/outline"
require "recording_studio_terms_and_conditions/outline_changes"
require "recording_studio_terms_and_conditions/outline_text"
require "recording_studio_terms_and_conditions/outline_edit"
require "recording_studio_terms_and_conditions/outline_release"
require "recording_studio_terms_and_conditions/outline_publish"
require "recording_studio_terms_and_conditions/outline_seed"
require "recording_studio_terms_and_conditions/outline_seed_actor"
require "recording_studio_terms_and_conditions/sole_live"
require "recording_studio_terms_and_conditions/agreement_history"
require "recording_studio_terms_and_conditions/published"
require "recording_studio_terms_and_conditions/kind_presence"
require "recording_studio_terms_and_conditions/privacy_route"
require "recording_studio_terms_and_conditions/table_page"
require "recording_studio_terms_and_conditions/gate"
require "recording_studio_terms_and_conditions/forces_acceptance"
require "recording_studio_terms_and_conditions/signup_registration"
require "recording_studio_terms_and_conditions/actor_search"
require "recording_studio_terms_and_conditions/acceptance_gate_installer"
require "recording_studio_terms_and_conditions/admin_widget_card"
require "recording_studio_terms_and_conditions/hide_admin_access_avatars"
require "recording_studio_terms_and_conditions/admin" if defined?(RecordingStudioAdmin)
require "recording_studio_terms_and_conditions/metrics"
require "recording_studio_terms_and_conditions/api"
require "recording_studio_terms_and_conditions/capabilities/terms_and_conditions"

module RecordingStudioTermsAndConditions
  class NotLive < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def library_root(actor: nil)
      LibraryRoot.recording(actor: actor)
    end

    def current_published_for(kind: Terms::DEFAULT_KIND)
      TermsAcceptance.current_published_for(kind: kind)
    end

    def current_published_by_kind
      TermsAcceptance.current_published_by_kind
    end

    def pending_published_for(actor)
      TermsAcceptance.pending_published_for(actor)
    end

    def pending_published_list(actor, *)
      TermsAcceptance.pending_published_list(actor)
    end

    def accepted?(actor, kind: Terms::DEFAULT_KIND)
      TermsAcceptance.accepted?(actor, kind: kind)
    end

    def requires_acceptance?(actor)
      TermsAcceptance.requires_acceptance?(actor)
    end

    def accept!(actor, version, provenance = {})
      TermsAcceptance.accept!(actor, version, provenance)
    end

    def reaccepting?(actor)
      TermsAcceptance.reaccepting?(actor)
    end

    def reaccepting_actors_for(recording_id:, terms_id:)
      TermsAcceptance.reaccepting_actors_for(recording_id: recording_id, terms_id: terms_id)
    end

    def accepted_any?(actor)
      TermsAcceptance.accepted_any?(actor)
    end
  end
end
