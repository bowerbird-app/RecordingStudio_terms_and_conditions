# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout if defined?(RecordingStudio::UsesDefaultLayout)
    helper RecordingStudioTermsAndConditions::ApplicationHelper
    helper RecordingStudioTermsAndConditions::TermsDateHelper
    helper RecordingStudio::LayoutHelper if defined?(RecordingStudio::LayoutHelper)
    helper RecordingStudioPublishable::ApplicationHelper if defined?(RecordingStudioPublishable::ApplicationHelper)

    # Isolated engines look up layouts in their own namespace first. Prepend the
    # host and Recording Studio view paths so `recording_studio/default_layout` resolves.
    if defined?(Rails.application) && Rails.application.respond_to?(:root)
      prepend_view_path Rails.application.root.join("app/views")
    end
    append_view_path RecordingStudio::Engine.root.join("app/views") if defined?(RecordingStudio::Engine)

    layout "recording_studio/default_layout"

    protect_from_forgery with: :exception
  end
end
