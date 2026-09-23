# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module ContinueNoticeHelper
    include TermsContextHelper
    include AgreeCopyHelper

    CONTINUE_NOTICE_SIZES = { xs: "text-xs", sm: "text-sm" }.freeze

    def recording_studio_terms_continue_notice(actor: nil, root: nil, pending: nil, size: :xs, link: true)
      documents = continue_notice_documents(actor, root, pending)
      return if documents.blank?

      content_tag(:div, class: "mt-3 mb-3") do
        if link
          continue_notice_with_modals(documents, size)
        else
          continue_notice_copy(documents, nil, nil, size, link: false)
        end
      end
    end

    private

    def continue_notice_with_modals(documents, size)
      terms_modal_id = "terms-continue-notice-#{SecureRandom.hex(4)}"
      privacy_modal_id = "privacy-continue-notice-#{SecureRandom.hex(4)}"
      parts = [continue_notice_copy(documents, terms_modal_id, privacy_modal_id, size, link: true)]
      parts << continue_notice_modal(terms_document(documents), terms_modal_id) if terms_document(documents)
      parts << continue_notice_modal(privacy_document(documents), privacy_modal_id) if privacy_document(documents)
      safe_join(parts)
    end

    def continue_notice_documents(actor, root, pending)
      root ||= recording_studio_terms_agree_root
      actor ||= recording_studio_terms_agree_actor
      return if pending.nil? && actor.present? &&
                !RecordingStudioTermsAndConditions.requires_acceptance?(actor, root)

      recording_studio_terms_pending_list(actor, root, pending)
    end

    def continue_notice_copy(documents, terms_modal_id, privacy_modal_id, size = :xs, link: true)
      content_tag(
        :p,
        continue_notice_sentence(documents, terms_modal_id, privacy_modal_id, link: link),
        class: continue_notice_copy_class(size)
      )
    end

    def continue_notice_copy_class(size)
      "#{continue_notice_size_class(size)} text-[var(--surface-muted-content-color)]"
    end

    def continue_notice_size_class(size)
      CONTINUE_NOTICE_SIZES.fetch(size.to_s.to_sym, CONTINUE_NOTICE_SIZES[:xs])
    end

    def continue_notice_sentence(documents, terms_modal_id, privacy_modal_id, link:)
      app_name = RecordingStudioTermsAndConditions.configuration.app_name
      prefix = if app_name.present?
                 safe_join(["By continuing, you agree to ", app_name, "'s "])
               else
                 "By continuing, you agree to the "
               end

      words = continue_notice_document_words(documents, terms_modal_id, privacy_modal_id, link: link)
      safe_join([prefix, words, "."])
    end

    def continue_notice_document_words(documents, terms_modal_id, privacy_modal_id, link:)
      parts = continue_notice_word_parts(documents, terms_modal_id, privacy_modal_id, link: link)
      parts = [continue_notice_terms_words(terms_modal_id, link: link)] if parts.empty?
      safe_join(parts)
    end

    def continue_notice_word_parts(documents, terms_modal_id, privacy_modal_id, link:)
      has_terms = terms_document(documents).present?
      has_privacy = privacy_document(documents).present?
      parts = []
      parts << continue_notice_terms_words(terms_modal_id, link: link) if has_terms
      return parts unless has_privacy

      parts << " and ".html_safe if has_terms
      parts << continue_notice_privacy_words(privacy_modal_id, link: link)
      parts
    end

    def continue_notice_terms_words(modal_id, link:)
      return "Terms & Conditions" unless link

      continue_notice_link(modal_id, "Terms & Conditions")
    end

    def continue_notice_privacy_words(modal_id, link:)
      return "privacy policy" unless link

      continue_notice_link(modal_id, "privacy policy")
    end

    def continue_notice_link(modal_id, text)
      render(
        FlatPack::Link::Component.new(
          href: "##{modal_id}",
          class: "text-[var(--color-primary)] underline underline-offset-[0.15em]",
          data: { modal_id: modal_id }
        ).with_content(text)
      )
    end

    def continue_notice_modal(terms, modal_id)
      return if terms.blank?

      render(FlatPack::Modal::Component.new(id: modal_id, size: :lg)) do |modal|
        modal.body { terms_standalone_document(terms) }
      end
    end

    def terms_standalone_document(terms)
      render(
        "recording_studio_terms_and_conditions/published_terms/document",
        terms: terms,
        preview_badge: nil
      )
    end
  end
end
