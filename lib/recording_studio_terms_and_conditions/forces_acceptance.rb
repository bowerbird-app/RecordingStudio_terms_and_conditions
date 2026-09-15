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
      return unless Gate.required?(self, signed_in_actor)

      remember_requested_page
      redirect_to Gate.acceptance_path(self), notice: terms_gate_notice
    end

    def terms_gate_notice
      root = Gate.root_for(self)
      pending = RecordingStudioTermsAndConditions.pending_published_list(signed_in_actor, root)
      labels = pending.map(&:kind_label)
      if RecordingStudioTermsAndConditions.reaccepting?(signed_in_actor, root)
        return "Terms changed. Agree again." if terms_only_pending?(pending)

        "#{labels.to_sentence} changed. Agree again."
      else
        return "One more thing — agree to the terms." if terms_only_pending?(pending)

        "One more thing — agree to #{labels.to_sentence}."
      end
    end

    def terms_only_pending?(pending)
      pending.size <= 1 && pending.first&.kind.to_s == Terms::DEFAULT_KIND
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
