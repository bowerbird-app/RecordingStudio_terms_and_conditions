# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module ContinueNoticeHelper
    include TermsContextHelper
    include AgreeCopyHelper

    CONTINUE_NOTICE_SIZES = { xs: "text-xs", sm: "text-sm" }.freeze

    def recording_studio_terms_continue_notice(actor: nil, root: nil, pending: nil, size: :xs, link: true)
      terms = continue_notice_terms(actor, root, pending)
      return if terms.blank?

      return continue_notice_copy(nil, size, link: false) unless link

      modal_id = "terms-continue-notice-#{SecureRandom.hex(4)}"
      safe_join([continue_notice_copy(modal_id, size, link: true), continue_notice_modal(terms, modal_id)])
    end

    private

    def continue_notice_terms(actor, root, pending)
      root ||= recording_studio_terms_agree_root
      actor ||= recording_studio_terms_agree_actor
      return if pending.nil? && actor.present? &&
                !RecordingStudioTermsAndConditions.requires_acceptance?(actor, root)

      recording_studio_terms_pending_list(actor, root, pending).first
    end

    def continue_notice_copy(modal_id, size = :xs, link: true)
      content_tag(:p, continue_notice_sentence(modal_id, link: link), class: continue_notice_copy_class(size))
    end

    def continue_notice_copy_class(size)
      "#{continue_notice_size_class(size)} text-[var(--surface-muted-content-color)]"
    end

    def continue_notice_size_class(size)
      CONTINUE_NOTICE_SIZES.fetch(size.to_s.to_sym, CONTINUE_NOTICE_SIZES[:xs])
    end

    def continue_notice_sentence(modal_id, link:)
      app_name = RecordingStudioTermsAndConditions.configuration.app_name
      prefix = if app_name.present?
                 safe_join(["By continuing, you agree to ", app_name, "'s "])
               else
                 "By continuing, you agree to the "
               end

      words = link ? continue_notice_link(modal_id) : "Terms & Conditions"
      safe_join([prefix, words, "."])
    end

    def continue_notice_link(modal_id)
      render(
        FlatPack::Link::Component.new(
          href: "##{modal_id}",
          class: "text-[var(--color-primary)] underline underline-offset-[0.15em]",
          data: { modal_id: modal_id }
        ).with_content("Terms & Conditions")
      )
    end

    def continue_notice_modal(terms, modal_id)
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
