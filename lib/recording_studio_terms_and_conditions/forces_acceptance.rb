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
      return unless signed_in_actor
      return if Gate.exempt?(self)

      pending = Gate.pending_for(self, signed_in_actor)
      return if pending.empty?

      remember_requested_page
      redirect_to Gate.acceptance_path(self), notice: terms_gate_notice
    end

    def terms_gate_notice
      root = Gate.root_for(self)
      if RecordingStudioTermsAndConditions.reaccepting?(signed_in_actor, root)
        "Terms changed. Agree again."
      else
        "One more thing — agree to the terms."
      end
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
