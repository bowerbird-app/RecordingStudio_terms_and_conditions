# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermsController < BaseController # rubocop:disable Metrics/ClassLength
      before_action :authorize_terms_index!, only: :index
      before_action :authorize_terms_write!, only: %i[new create edit update release]
      before_action :authorize_terms_show!, only: %i[show changes preview text]

      def index
        hub = RecordingStudioTermsAndConditions.admin_hub_path
        redirect_to "#{hub}/screens/recording_studio_terms"
      end

      def new
        @available_kinds = KindPresence.available_kinds
        if @available_kinds.empty?
          redirect_to admin_terms_path,
                      alert: "Terms and a Privacy Policy already exist. Edit a version to change them."
          return
        end

        assign_form_fields(title: "", body: "", kind: @available_kinds.first)
      end

      def create
        recording = write_terms_resource!(:new, terms_parent_root, audit_action: :create) { draft_from_params }
        redirect_to admin_term_path(recording), notice: "Terms drafted. Publish when they are ready."
      rescue TermsCreate::KindTaken
        render_create_blocked
      rescue ActiveRecord::RecordInvalid => e
        @available_kinds = KindPresence.available_kinds
        render_invalid_terms(:new, e, "Could not save that draft.")
      end

      def show
        @terms = terms_recording.recordable
        @changes = Outline.changes(terms_recording)
        @unreleased = @changes.any?
        @live = Outline.live?(terms_recording)
        @current_version = AgreementHistory.find(terms_recording, @terms.id) if @live
        @agreement_count = @current_version&.agreement_count
      end

      def edit
        redirect_to admin_term_path(terms_recording)
      end

      def update
        redirect_to admin_term_path(terms_recording), alert: "Edit a section or a clause, then release."
      end

      def text
        @terms = terms_recording.recordable
        @version = params[:version].to_s == "next" ? "next" : "live"
        preview = Outline.preview(terms_recording)
        @document_title = @version == "next" ? preview[:title] : @terms.title
        @document_body = @version == "next" ? preview[:body] : @terms.body
      end

      def changes
        @terms = terms_recording.recordable
        @changes = Outline.changes(terms_recording)
        @unreleased = Outline.unreleased?(terms_recording)
      end

      def preview
        @terms = terms_recording.recordable
        @preview = Outline.preview(terms_recording, title: params.dig(:terms, :title))
        @unreleased = Outline.unreleased?(terms_recording, title: params.dig(:terms, :title))
      end

      def release
        released = Outline.release(terms_recording, actor: current_admin_actor, title: params.dig(:terms, :title))
        redirect_to admin_term_path(released), notice: "Released. People will need to agree to this version."
      rescue Outline::Unchanged => e
        redirect_to admin_term_path(terms_recording), alert: e.message
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

      def draft_from_params
        TermsCreate.call(
          actor: current_admin_actor,
          title: terms_params[:title],
          body: terms_params[:body],
          kind: terms_params[:kind]
        )
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

      def render_invalid_terms(template, error, fallback)
        flash.now[:alert] = error.record.errors.full_messages.to_sentence.presence || fallback
        assign_form_fields_from_params
        render template, status: :unprocessable_entity
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

      def render_create_blocked
        kind = Terms.normalize_kind(terms_params[:kind])
        flash.now[:alert] = KindPresence.blocked_message(kind)
        @available_kinds = KindPresence.available_kinds
        assign_form_fields_from_params
        render :new, status: :unprocessable_entity
      end

      def terms_params
        params.fetch(:terms, {}).permit(:title, :body, :kind)
      end
    end
  end
end
