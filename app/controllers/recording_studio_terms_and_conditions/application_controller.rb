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

    # Flatpack 0.1.195+ paints `.fp-button[data-fp-style]` from kit CSS. Hosts that
    # only load `flat_pack/variables` leave primary Continue looking like a bare
    # bordered control. Append the kit sheet so Agree/Accept still fill primary.
    before_action :ensure_flatpack_application_stylesheet

    protect_from_forgery with: :exception

    private

    def ensure_flatpack_application_stylesheet
      view_context.content_for(
        :head,
        helpers.stylesheet_link_tag("flat_pack/application", "data-turbo-track": "reload")
      )
    end
  end
end
