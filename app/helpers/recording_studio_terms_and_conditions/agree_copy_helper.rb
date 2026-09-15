# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Kind-aware Agree and Admin Users copy.
  module AgreeCopyHelper
    def terms_agree_heading(documents)
      list = Array(documents).compact
      return list.first.title if list.size == 1

      list.many? ? "Agree" : "Terms"
    end

    def terms_agree_subtitle(documents, reaccepting)
      list = Array(documents).compact
      return terms_agree_reaccept_subtitle(list) if reaccepting
      return "The live version for this workspace." if list.size <= 1

      "Read every document. One tick covers the lot."
    end

    def terms_reaccept_alert_title(terms_list)
      list = Array(terms_list).compact
      return "Terms updated" if list.size <= 1 && list.first&.kind.to_s == Terms::DEFAULT_KIND
      return "#{list.first.kind_label} updated" if list.size == 1

      "Documents updated"
    end

    def terms_users_subtitle(terms)
      return "People who ticked the box for these terms." if terms&.kind.to_s == Terms::DEFAULT_KIND

      "People who ticked the box for this #{terms.kind_label.downcase}."
    end

    private

    def terms_agree_reaccept_subtitle(list)
      kind = list.first&.kind.to_s
      if list.size <= 1 && (kind.blank? || kind == Terms::DEFAULT_KIND)
        return "These terms changed. Agree again to stay in."
      end
      return "#{list.first.kind_label} changed. Agree again to stay in." if list.size == 1

      "Some of these changed. Read them, then tick once."
    end
  end
end
