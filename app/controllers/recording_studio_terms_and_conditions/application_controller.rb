# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout if defined?(RecordingStudio::UsesDefaultLayout)
    helper RecordingStudioTermsAndConditions::ApplicationHelper

    protect_from_forgery with: :exception
  end
end
