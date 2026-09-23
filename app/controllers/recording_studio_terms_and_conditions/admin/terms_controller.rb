# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermsController < BaseController # rubocop:disable Metrics/ClassLength
      before_action :authorize_terms_index!, only: :index
      before_action :authorize_terms_write!, only: %i[new create edit update]
      before_action :authorize_terms_show!, only: :show

      def index
        @pagy, @terms_recordings = paginate_table(terms_scope)
      end

      def new
        @available_kinds = KindPresence.available_kinds(terms_parent_root)
        if @available_kinds.empty?
          redirect_to admin_terms_path,
                      alert: "This workspace already has Terms and a Privacy Policy. Edit a version to change them."
          return
        end

        assign_form_fields(title: "", body: "", kind: @available_kinds.first)
      end

      def create
        return render_missing_workspace if terms_parent_root.blank?
        return render_create_blocked if create_kind_taken?

        recording = write_terms_resource!(:new, terms_parent_root, audit_action: :create) do
          draft_terms!(terms_parent_root)
        end
        redirect_to admin_term_path(recording), notice: "Terms drafted. Publish when they are ready."
      rescue ActiveRecord::RecordInvalid => e
        @available_kinds = KindPresence.available_kinds(terms_parent_root)
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
        recording = persist_terms_update!
        redirect_to admin_term_path(recording), notice: terms_write_notice(recording)
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
        @available_kinds = KindPresence.available_kinds(nil)
        assign_form_fields_from_params
        render :new, status: :unprocessable_entity
      end

      def render_invalid_terms(template, error, fallback)
        flash.now[:alert] = error.record.errors.full_messages.to_sentence.presence || fallback
        assign_form_fields_from_params
        render template, status: :unprocessable_entity
      end

      def persist_terms_update!
        write_terms_resource!(:edit, terms_recording, audit_action: :update) do
          TermsWrite.call(
            recording: terms_recording,
            actor: current_admin_actor,
            title: terms_params[:title],
            body: terms_params[:body],
            kind: terms_recording.recordable&.kind
          )
        end
      end

      def terms_write_notice(recording)
        if recording.id == terms_recording.id
          "Terms updated."
        else
          "Draft saved. The live copy stays until you publish."
        end
      end

      def assign_terms_fields(terms)
        terms.title = terms_params[:title]
        terms.body = terms_params[:body]
        terms.kind = Terms.normalize_kind(terms_params[:kind])
      end

      def assign_form_fields_from(terms)
        assign_form_fields(
          title: terms.title,
          body: terms.body,
          kind: terms.kind.presence || Terms::DEFAULT_KIND
        )
      end

      def assign_form_fields_from_params
        assign_form_fields(
          title: terms_params[:title],
          body: terms_params[:body],
          kind: terms_params[:kind].presence || Terms::DEFAULT_KIND
        )
      end

      def assign_form_fields(title:, body:, kind: Terms::DEFAULT_KIND)
        @title = title
        @body = body
        @kind = kind
      end

      def create_blocked_message(kind)
        label = Terms.kind_label_for(kind)
        "This workspace already has #{label}. Open that version and edit to make a new draft."
      end

      def create_kind_taken?
        KindPresence.exists?(terms_parent_root, kind: Terms.normalize_kind(terms_params[:kind]))
      end

      def render_create_blocked
        kind = Terms.normalize_kind(terms_params[:kind])
        flash.now[:alert] = create_blocked_message(kind)
        @available_kinds = KindPresence.available_kinds(terms_parent_root)
        assign_form_fields_from_params
        render :new, status: :unprocessable_entity
      end

      def terms_params
        params.fetch(:terms, {}).permit(:title, :body, :kind)
      end
    end
  end
end
