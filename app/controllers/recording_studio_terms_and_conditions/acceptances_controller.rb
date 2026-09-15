# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class AcceptancesController < ApplicationController
    before_action :authenticate_user!, raise: false

    def show
      load_acceptance_context
    end

    def create
      load_acceptance_context
      return reject_agreement("Tick the box if you agree.") unless agreed?
      return reject_agreement("There are no live terms to agree to.") if @terms.blank?

      accept_current_terms!
    end

    private

    def load_acceptance_context
      @root = acceptance_root
      @terms = RecordingStudioTermsAndConditions.current_published_for(@root)
      @already_accepted = RecordingStudioTermsAndConditions.accepted?(current_actor, @root)
    end

    def reject_agreement(message)
      flash.now[:alert] = message
      @already_accepted = false
      render :show, status: :unprocessable_entity
    end

    def accept_current_terms!
      RecordingStudioTermsAndConditions.accept!(current_actor, @terms, clickwrap_provenance)
      redirect_to next_path_after_acceptance, notice: "You're in. Thanks for reading."
    end

    def clickwrap_provenance
      provenance = { "source" => "clickwrap" }
      return provenance unless RecordingStudioTermsAndConditions.configuration.capture_request_provenance

      provenance.merge(
        "ip" => request.remote_ip.to_s,
        "user_agent" => request.user_agent.to_s
      )
    end

    def next_path_after_acceptance
      stored = stored_location_for(:user) if respond_to?(:stored_location_for)
      return stored if stored.present? && stored != acceptance_path

      main_app.root_path
    end

    def acceptance_root
      return current_root_recordable if respond_to?(:current_root_recordable, true) && current_root_recordable

      current_root_recording if respond_to?(:current_root_recording, true)
    end

    def agreed?
      ActiveModel::Type::Boolean.new.cast(params[:agreed])
    end

    def current_actor
      return current_user if respond_to?(:current_user)

      Current.actor if defined?(Current)
    end
  end
end
