# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class AcceptancesController < ApplicationController
    before_action :authenticate_user!, raise: false

    def show
      load_acceptance_context
      @return_to = safe_return_path(stored_location_for(:user))
    end

    def create
      load_acceptance_context
      @return_to = safe_return_path(params[:return_to])
      return reject_agreement(Copy.t("flashes.no_live_terms")) if documents_to_accept.blank?

      accept_current_terms!
    end

    private

    def load_acceptance_context
      @pending_terms = RecordingStudioTermsAndConditions.pending_published_list(current_actor)
      @terms = @pending_terms.first || RecordingStudioTermsAndConditions.current_published_for
      @already_accepted = @pending_terms.empty? && @terms.present?
      @reaccepting = RecordingStudioTermsAndConditions.accepted_any?(current_actor)
    end

    def reject_agreement(message)
      flash.now[:alert] = message
      @already_accepted = false
      render :show, status: :unprocessable_entity
    end

    def accept_current_terms!
      documents_to_accept.each do |terms|
        RecordingStudioTermsAndConditions.accept!(current_actor, terms, continue_notice_provenance)
      end
      redirect_to next_path_after_acceptance
    rescue RecordingStudioTermsAndConditions::NotLive
      reject_agreement(Copy.t("flashes.not_live"))
    end

    def documents_to_accept
      list = @pending_terms.presence || Array(@terms).compact
      list.uniq { |terms| [terms.class.name, terms.id] }
    end

    def continue_notice_provenance
      provenance = { "source" => "continue_notice" }
      return provenance unless RecordingStudioTermsAndConditions.configuration.capture_request_provenance

      provenance.merge(
        "ip" => request.remote_ip.to_s,
        "user_agent" => request.user_agent.to_s
      )
    end

    def next_path_after_acceptance
      @return_to.presence || main_app.root_path
    end

    def safe_return_path(location)
      path = url_from(location)
      return if path.blank? || agree_path?(path)

      path
    end

    def agree_path?(path)
      location = URI.parse(path.to_s).path.to_s.chomp("/")
      location.casecmp?(acceptance_path.chomp("/"))
    rescue URI::InvalidURIError
      false
    end

    def current_actor
      return current_user if respond_to?(:current_user)

      Current.actor if defined?(Current)
    end
  end
end
