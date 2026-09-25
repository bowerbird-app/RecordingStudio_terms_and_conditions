# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module DocumentButtonHelper
    def recording_studio_terms_document_button(terms)
      modal_id = agree_document_modal_id(terms)
      safe_join([agree_document_view_button(terms, modal_id), continue_notice_modal(terms, modal_id)])
    end

    private

    def agree_document_modal_id(terms)
      "agree-document-#{terms.id}"
    end

    def agree_document_view_button(terms, modal_id)
      render(
        FlatPack::Button::Component.new(
          text: terms_view_button_label(terms),
          style: :secondary,
          href: "##{modal_id}",
          class: "w-full",
          data: { modal_id: modal_id }
        )
      )
    end
  end
end
