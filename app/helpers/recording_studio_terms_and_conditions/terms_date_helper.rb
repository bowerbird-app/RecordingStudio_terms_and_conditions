# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module TermsDateHelper
    TERMS_DATE_FORMAT = "%e %b %Y"

    def terms_published_at(recording)
      return unless recording

      recording.try(:current_publishable)&.try(:publish_at) || live_terms_updated_at(recording)
    end

    def terms_version_date(terms, recording: nil)
      time = terms_version_time(terms, recording)
      return if time.blank?

      content_tag(
        :time,
        terms_calendar_date(time),
        datetime: time.in_time_zone.iso8601,
        class: "text-sm text-[var(--surface-muted-content-color)]"
      )
    end

    def terms_calendar_date(time)
      return if time.blank?

      time.in_time_zone.strftime(TERMS_DATE_FORMAT).squish
    end

    def terms_heading_date(terms, recording: nil)
      terms_calendar_date(terms_version_time(terms, recording))
    end

    def terms_reaccept_notice(terms, recording: nil)
      date = terms_calendar_date(terms_version_time(terms, recording))
      "You already agreed. This version is from #{date}."
    end

    private

    def live_terms_updated_at(recording)
      return unless recording.respond_to?(:currently_published?) && recording.currently_published?

      recording.updated_at
    end

    def terms_version_time(terms, recording)
      recording ||= RecordingStudio::Recording.find_by(
        recordable_type: Terms.name,
        recordable_id: terms.try(:id)
      )
      terms_published_at(recording) ||
        recording&.updated_at ||
        recording&.created_at ||
        terms.try(:created_at)
    end
  end
end
