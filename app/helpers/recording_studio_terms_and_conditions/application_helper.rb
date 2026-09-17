# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module ApplicationHelper
    include AgreeHelper
    include TablePaginationHelper
    include TermsDateHelper

    TERMS_BODY_PLACEHOLDER = "Write the terms people will agree to."
    TERMS_BODY_EDITOR_OPTIONS = {
      preset: :content,
      format: :html,
      toolbar: :standard,
      placeholder: TERMS_BODY_PLACEHOLDER
    }.freeze

    def terms_page_nav(title:, back_url: nil, back_label: "Back")
      recording_studio_page_nav(
        title: title,
        page_nav_back_url: back_url,
        page_nav_back_label: back_label
      )
    end

    def terms_publishable_edit_path(recording)
      return unless recording && respond_to?(:recording_studio_publishable)

      recording_studio_publishable.edit_recording_publishable_path(recording_id: recording.id)
    end

    def terms_publishable_quick_actions(recording)
      return unless recording
      return unless defined?(RecordingStudioPublishable::QuickActions::Component)

      render RecordingStudioPublishable::QuickActions::Component.new(recording: recording)
    end

    def terms_public_url(terms)
      terms.try(:published_url)
    end

    def terms_admin_hub_path
      if defined?(RecordingStudioAdmin)
        RecordingStudioAdmin.configuration.default_mount_path.presence || "/admin"
      else
        admin_terms_path
      end
    end

    def terms_body(text)
      html = text.to_s
      sanitized = if defined?(FlatPack::RichTextSanitizer)
                    FlatPack::RichTextSanitizer.sanitize(html)
                  else
                    sanitize(html)
                  end

      return simple_format(html) unless html.include?("<")

      sanitized.html_safe
    end

    def terms_content(text)
      body = terms_body(text)
      return if body.blank?

      render(FlatPack::Content::Component.new) { body }
    end

    def terms_body_editor(value:)
      render FlatPack::TextArea::Component.new(
        name: "terms[body]",
        value: value,
        label: "Body",
        required: true,
        placeholder: TERMS_BODY_PLACEHOLDER,
        rich_text: true,
        rich_text_options: TERMS_BODY_EDITOR_OPTIONS
      )
    end
  end
end
