# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module OutlineHelper
    def review_words(value)
      strip_tags(value.to_s).squish.presence || "—"
    end

    def terms_clause_count(section)
      count = section.clauses.size
      return "No clauses" if count.zero?
      return "1 clause" if count == 1

      "#{count} clauses"
    end

    def terms_clause_preview(body)
      text = strip_tags(body.to_s).squish
      text.split(/(?<=[.!?])\s+/, 3).first(2).join(" ").presence || "—"
    end

    def terms_changed_badge(changes, id)
      changed_badge if terms_changed?(changes, id)
    end

    def terms_section_changed_badge(changes, section)
      ids = [section.id, *section.clauses.map(&:id)]
      changed_badge if ids.any? { |id| terms_changed?(changes, id) }
    end

    def terms_changed?(changes, id)
      Array(changes).any? { |change| change.id.to_s == id.to_s }
    end

    def changed_badge
      render FlatPack::Badge::Component.new(text: "Changed", style: :warning, size: :sm)
    end
  end
end
