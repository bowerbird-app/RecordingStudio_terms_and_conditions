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

    def terms_change_summary(changes)
      parts = terms_change_parts(changes)
      return "No unreleased changes" if parts.empty?

      "#{parts.join(', ')}."
    end

    def terms_agreed_count(count)
      number = count.to_i
      number == 1 ? "1 agreed" : "#{number} agreed"
    end

    def terms_version_label(version)
      when_text = terms_host_time(version.released_at)
      return "Version #{version.number}" if when_text.blank?

      "Version #{version.number} · released #{when_text}"
    end

    def terms_version_trailing(version)
      pieces = []
      pieces << render(FlatPack::Badge::Component.new(text: "Live", style: :success, size: :sm)) if version.live
      pieces << content_tag(:span, terms_agreed_count(version.agreement_count))
      safe_join(pieces, " ")
    end

    def terms_change_parts(changes)
      entries = Array(changes)
      [%w[section added], %w[section changed], %w[section moved], %w[section removed],
       %w[clause added], %w[clause changed], %w[clause moved], %w[clause removed]].filter_map do |kind, status|
        count = entries.count { |entry| entry.kind == kind && entry.status == status }
        next if count.zero?

        "#{count} #{count == 1 ? kind : "#{kind}s"} #{status}"
      end
    end
  end
end
