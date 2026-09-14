# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class PublishedTermsController < ApplicationController
    layout "recording_studio_terms_and_conditions/public"

    skip_before_action :authenticate_user!, raise: false
    skip_recording_studio_root_resolution if respond_to?(:skip_recording_studio_root_resolution)

    def show
      @terms = @parent_recordable || @recordable
      head :not_found unless @terms.is_a?(Terms)
    end
  end
end
