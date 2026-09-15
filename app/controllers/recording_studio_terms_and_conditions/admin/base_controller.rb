# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class BaseController < RecordingStudioTermsAndConditions::ApplicationController
      include Pagy::Backend
      include TablePage

      before_action :authenticate_user!, raise: false
      before_action :require_admin_access!

      private

      def require_admin_access!
        return if admin_authorized?(:view)

        head :forbidden
      end

      def require_admin_write_access!
        return if admin_authorized?(:edit)

        head :forbidden
      end

      def admin_authorized?(role)
        return true unless defined?(RecordingStudioAccessible) && defined?(RecordingStudioAdmin)

        access_recording = RecordingStudioAdmin.configuration.access_recording_resolver&.call(admin_context)
        return false unless access_recording

        RecordingStudioAccessible.authorized?(
          actor: current_admin_actor,
          recording: access_recording,
          role: role
        )
      end

      def admin_context
        RecordingStudioAdmin::Context.new(controller: self) if defined?(RecordingStudioAdmin::Context)
      end

      def current_admin_actor
        return current_user if respond_to?(:current_user)

        Current.actor if defined?(Current)
      end

      def terms_recording
        @terms_recording ||= RecordingStudio::Recording.find_by!(
          id: params[:term_id] || params[:id],
          recordable_type: Terms.name,
          trashed_at: nil
        )
      end

      def terms_parent_root
        recording = current_root_recording if respond_to?(:current_root_recording, true)
        return recording if recording&.recordable_type == "Workspace"

        RecordingStudio::Recording.find_by(
          parent_recording_id: nil,
          trashed_at: nil,
          recordable_type: "Workspace"
        )
      end
    end
  end
end
