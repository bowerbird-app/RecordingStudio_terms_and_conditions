# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermsController < BaseController
      before_action :authorize_terms_index!, only: :index
      before_action :authorize_terms_write!, only: %i[new create edit update]
      before_action :authorize_terms_show!, only: :show

      def index
        @pagy, @terms_recordings = paginate_table(terms_scope)
      end

      def new
        assign_form_fields(title: "", body: "")
      end

      def create
        return render_missing_workspace if terms_parent_root.blank?

        recording = write_terms_resource!(:new, terms_parent_root, audit_action: :create) do
          draft_terms!(terms_parent_root)
        end
        redirect_to admin_term_path(recording), notice: "Terms drafted. Publish when they are ready."
      rescue ActiveRecord::RecordInvalid => e
        render_invalid_terms(:new, e, "Could not save that draft.")
      end

      def show
        @terms = terms_recording.recordable
      end

      def edit
        @terms = terms_recording.recordable
        assign_form_fields_from(@terms)
      end

      def update
        recording = write_terms_resource!(:edit, terms_recording, audit_action: :update) do
          terms_recording.root_recording.revise(terms_recording, actor: current_admin_actor) do |terms|
            assign_terms_fields(terms)
          end
        end
        redirect_to admin_term_path(recording), notice: "Terms updated."
      rescue ActiveRecord::RecordInvalid => e
        @terms = terms_recording.recordable
        render_invalid_terms(:edit, e, "Could not save that version.")
      end

      private

      def authorize_terms_index!
        authorize_terms_resource!(:index)
      end

      def authorize_terms_write!
        authorize_terms_resource!(terms_resource_action, record: write_terms_record)
      end

      def authorize_terms_show!
        authorize_terms_resource!(:show, record: terms_recording)
      end

      def write_terms_record
        %w[new create].include?(action_name) ? nil : terms_recording
      end

      def write_terms_resource!(action, record, audit_action:)
        return yield unless defined?(RecordingStudioAdmin::AdminActionAuditing)

        result = nil
        perform_recording_studio_admin_action!("terms", action, record, audit_action: audit_action) do
          result = yield
          true
        end
        result
      end

      def terms_scope
        RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
                                  .preload(:recordable)
                                  .order(updated_at: :desc)
      end

      def draft_terms!(parent)
        parent.record(Terms, actor: current_admin_actor, parent_recording: parent) do |terms|
          assign_terms_fields(terms)
        end
      end

      def render_missing_workspace
        flash.now[:alert] = "Pick a workspace first."
        assign_form_fields_from_params
        render :new, status: :unprocessable_entity
      end

      def render_invalid_terms(template, error, fallback)
        flash.now[:alert] = error.record.errors.full_messages.to_sentence.presence || fallback
        assign_form_fields_from_params
        render template, status: :unprocessable_entity
      end

      def assign_terms_fields(terms)
        terms.title = terms_params[:title]
        terms.body = terms_params[:body]
      end

      def assign_form_fields_from(terms)
        assign_form_fields(title: terms.title, body: terms.body)
      end

      def assign_form_fields_from_params
        assign_form_fields(title: terms_params[:title], body: terms_params[:body])
      end

      def assign_form_fields(title:, body:)
        @title = title
        @body = body
      end

      def terms_params
        params.fetch(:terms, {}).permit(:title, :body)
      end
    end
  end
end
