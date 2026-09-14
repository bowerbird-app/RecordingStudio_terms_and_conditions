# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class AcceptancesController < ApplicationController
    before_action :authenticate_user!, raise: false

    def show
      @root = acceptance_root
      @terms = RecordingStudioTermsAndConditions.current_published_for(@root)
      @already_accepted = RecordingStudioTermsAndConditions.accepted?(current_actor, @root)
    end

    def create
      @root = acceptance_root
      @terms = RecordingStudioTermsAndConditions.current_published_for(@root)

      unless agreed?
        flash.now[:alert] = "Tick the box if you agree."
        @already_accepted = false
        return render :show, status: :unprocessable_entity
      end

      if @terms.blank?
        flash.now[:alert] = "There are no live terms to agree to."
        return render :show, status: :unprocessable_entity
      end

      RecordingStudioTermsAndConditions.accept!(
        current_actor,
        @terms,
        { "source" => "clickwrap" }
      )
      redirect_to acceptance_path, notice: "You're in. Thanks for reading."
    end

    private

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
