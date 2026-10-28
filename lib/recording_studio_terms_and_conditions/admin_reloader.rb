# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module AdminReloader
    module_function

    def call
      return unless defined?(RecordingStudioAdmin)

      admin = RecordingStudioTermsAndConditions::Admin
      admin.reset_definition_constants! if admin.respond_to?(:reset_definition_constants!)
      load File.expand_path("admin.rb", __dir__)
      RecordingStudioTermsAndConditions::Admin.register!
      prepend_widget_card
      prepend_button_href
      hide_access_avatars
    end

    def prepend_widget_card
      helper = RecordingStudioAdmin::WidgetRenderingHelper
      return if helper.ancestors.include?(RecordingStudioTermsAndConditions::AdminWidgetCard)

      helper.prepend RecordingStudioTermsAndConditions::AdminWidgetCard
    end

    def prepend_button_href
      button = FlatPack::Button::Component
      return if button.ancestors.include?(RecordingStudioTermsAndConditions::FlatpackButtonHrefFromUrl)

      button.prepend RecordingStudioTermsAndConditions::FlatpackButtonHrefFromUrl
    end

    def hide_access_avatars
      return unless defined?(RecordingStudioAdmin::ApplicationController)

      hide_access = RecordingStudioTermsAndConditions::HideAdminAccessAvatars
      admin_helpers = RecordingStudioAdmin::ApplicationController._helpers
      admin_helpers.prepend hide_access unless admin_helpers.ancestors.include?(hide_access)
    end
  end
end
