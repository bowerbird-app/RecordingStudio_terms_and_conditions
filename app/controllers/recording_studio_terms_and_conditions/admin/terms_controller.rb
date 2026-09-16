# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Admin
    class TermsController < BaseController
      before_action :require_admin_write_access!, only: %i[create update]

      def index
        @category_filter = filtered_category
        @category_coverage = CategoryCoverage.rows(terms_scope.to_a)
        @pagy, @terms_recordings = paginate_table(filtered_terms_scope)
      end

      def new
        assign_form_fields(
          title: "",
          body: "",
          change_note: "",
          category: Terms::DEFAULT_CATEGORY
        )
      end

      def create
        return render_missing_workspace if terms_parent_root.blank?

        recording = draft_terms!(terms_parent_root)
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
        @change_note = ""
      end

      def update
        recording = terms_recording.root_recording.revise(terms_recording, actor: current_admin_actor) do |terms|
          assign_terms_fields(terms)
        end
        redirect_to admin_term_path(recording), notice: "Terms updated."
      rescue ActiveRecord::RecordInvalid => e
        @terms = terms_recording.recordable
        render_invalid_terms(:edit, e, "Could not save that version.")
      end

      private

      def terms_scope
        RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
                                  .preload(:recordable)
                                  .order(updated_at: :desc)
      end

      def filtered_terms_scope
        category = filtered_category
        return terms_scope if category.blank?

        terms_scope.where(recordable_id: Terms.where(category: category).select(:id))
      end

      def filtered_category
        category = Terms.normalize_category(params[:category])
        category if params[:category].present? && Terms::CATEGORIES.include?(category)
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
        terms.change_note = terms_params[:change_note].presence
        terms.category = terms_params[:category].presence || Terms::DEFAULT_CATEGORY
      end

      def assign_form_fields_from(terms)
        assign_form_fields(
          title: terms.title,
          body: terms.body,
          change_note: terms.change_note,
          category: terms.category.presence || Terms::DEFAULT_CATEGORY
        )
      end

      def assign_form_fields_from_params
        assign_form_fields(
          title: terms_params[:title],
          body: terms_params[:body],
          change_note: terms_params[:change_note],
          category: terms_params[:category].presence || Terms::DEFAULT_CATEGORY
        )
      end

      def assign_form_fields(title:, body:, change_note:, category:)
        @title = title
        @body = body
        @change_note = change_note
        @category = category
      end

      def terms_params
        params.fetch(:terms, {}).permit(:title, :body, :change_note, :category)
      end
    end
  end
end
