# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Outline
    class << self
      def seed_recording!(terms_recording, actor:)
        return repair_stored_generated_numbers!(terms_recording, actor: actor) if sections(terms_recording).any?

        drafts = split(terms_recording.recordable.body, title: terms_recording.recordable.title)
        ActiveRecord::Base.transaction do
          create_drafts(terms_recording, drafts, actor)
          write_baseline(terms_recording) if live?(terms_recording)
        end
        terms_recording
      end

      def seed_all!(actor:)
        seeded = 0
        scope = RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
        scope.find_each { |recording| seeded += 1 if seed_recording!(recording, actor: actor) }
        seeded
      end

      private

      def create_drafts(terms_recording, drafts, actor)
        drafts.each do |draft|
          section = add_section(terms_recording, heading: draft.heading, actor: actor)
          draft.clauses.each { |body| add_clause(section, body: body, actor: actor) }
        end
      end

      def repair_stored_generated_numbers!(terms_recording, actor:)
        changed = false
        sections(terms_recording).each { |section| changed |= repair_section_numbers(section, actor) }
        terms_recording if changed
      end

      def repair_section_numbers(section, actor)
        heading = strip_heading_number(section.heading, number: section.number)
        stripped_heading = heading != section.heading
        edit_section(section.recording, heading: heading, actor: actor) if stripped_heading
        stripped_clauses = section.clauses.filter_map { |clause| repair_clause_row(clause, actor) }.any?
        stripped_heading || stripped_clauses
      end

      def repair_clause_row(clause, actor)
        body = strip_clause_number(clause.body, number: clause.number)
        return if body == clause.body

        edit_clause(clause.recording, body: body, actor: actor)
      end

      def write_baseline(terms_recording)
        payload = manifest_payload(terms_recording)
        Terms.where(id: terms_recording.recordable_id).update_all(release_manifest: payload)
        terms_recording.recordable.release_manifest = payload
      end
    end
  end
end
