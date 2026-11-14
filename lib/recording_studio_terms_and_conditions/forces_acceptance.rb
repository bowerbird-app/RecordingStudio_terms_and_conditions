# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Redirect signed-in people to the clickwrap until they accept live Terms.
  module ForcesAcceptance
    extend ActiveSupport::Concern

    included do
      before_action :force_terms_acceptance
    end

    def after_sign_in_path_for(resource)
      Gate.after_auth_path(self, resource) || super
    end

    def after_sign_up_path_for(resource)
      Gate.after_auth_path(self, resource) || super
    end

    private

    def force_terms_acceptance
      actor = signed_in_actor
      return unless actor
      return if Gate.exempt?(self)

      decision = RecordingStudio.check_gate(Gate::GATE_NAME, actor: actor, controller: self)
      return if decision.allowed?

      remember_requested_page
      # A raised check denies with no redirect. Agree stays exempt, so this does not loop.
      redirect_to decision.redirect_to || Gate.acceptance_path(self)
    end

    def signed_in_actor
      return current_user if respond_to?(:current_user) && current_user

      Current.actor if defined?(Current)
    end

    def remember_requested_page
      return unless request.get?
      return unless respond_to?(:store_location_for)

      store_location_for(:user, request.fullpath)
    end
  end
end
