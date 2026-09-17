# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class BaseController < RecordingStudioTermsAndConditions::ApplicationController
      include ::Pagy::Backend
      include TablePage
      include RecordingStudioAdmin::AdminActionAuditing if defined?(RecordingStudioAdmin::AdminActionAuditing)

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

        access_recording = recording_studio_admin_context&.access_recording
        return false unless access_recording

        RecordingStudioAccessible.authorized?(
          actor: current_admin_actor,
          recording: access_recording,
          role: role
        )
      end

      def recording_studio_admin_context
        return unless defined?(RecordingStudioAdmin::Context)

        @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
          params: params.to_unsafe_h,
          current_actor: current_admin_actor,
          controller: self,
          routes: self,
          view_context: view_context
        )
      end
      alias admin_context recording_studio_admin_context

      def authorize_terms_resource!(action = nil, record: nil)
        return require_admin_write_access! unless defined?(RecordingStudioAdmin)

        authorize_registered_terms_resource!(action || terms_resource_action, record)
      end

      def authorize_registered_terms_resource!(action, record)
        RecordingStudioAdmin.authorize_resource!(
          key: "terms",
          action: action,
          context: recording_studio_admin_context,
          record: record,
          audit: true,
          audit_action: action_name
        )
      rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
        head :forbidden
      end

      def terms_resource_action
        case action_name
        when "create" then :new
        when "update" then :edit
        else action_name.to_sym
        end
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
