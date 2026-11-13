# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Outline # rubocop:disable Metrics/ModuleLength
    Entry = Struct.new(
      :kind, :status, :id, :number, :previous_number,
      :heading, :previous_heading, :body, :previous_body,
      :section_id, :previous_section_id,
      keyword_init: true
    )

    class << self # rubocop:disable Metrics/ClassLength
      def changes(terms_recording)
        current = sections(terms_recording)
        previous = manifest_sections(terms_recording)
        return added_tree(current) if previous.nil?

        diff_tree(current, previous)
      end

      def unreleased?(terms_recording, title: nil)
        title_differs?(terms_recording, title) || changes(terms_recording).any?
      end

      def title_differs?(terms_recording, title)
        return false if title.blank?

        title.to_s != terms_recording.recordable.title.to_s
      end

      private

      def added_tree(current)
        current.flat_map { |section| added_section(section) }
      end

      def added_section(section)
        [section_entry(section, "added")] + section.clauses.map { |clause| clause_entry(clause, section, "added") }
      end

      def diff_tree(current, previous)
        section_entries(current, previous) + clause_entries(current, previous)
      end

      def section_entries(current, previous) # rubocop:disable Metrics/AbcSize
        prior = index_manifest_sections(previous)
        current_ids = current.map { |section| section.id.to_s }
        kept = current.each_with_index.filter_map do |section, index|
          changed_section(section, prior[section.id.to_s], index)
        end
        removed = previous.each_with_index.filter_map do |row, index|
          removed_section(row, index) unless current_ids.include?(row["recording_id"].to_s)
        end
        kept + removed
      end

      def changed_section(section, prior, index)
        status = section_status(section, prior, index)
        return if status == "unchanged"

        section_entry(
          section,
          status,
          previous_number: prior && display_number(prior[:index]),
          previous_heading: prior && prior[:heading]
        )
      end

      def section_status(section, prior, index)
        return "added" if prior.nil?
        return "changed" if section.heading != prior[:heading]
        return "moved" if index != prior[:index]

        "unchanged"
      end

      def clause_entries(current, previous)
        now = index_clauses(current)
        was = index_manifest_clauses(previous)
        kept = now.filter_map { |id, row| changed_clause(row, was[id]) }
        removed = was.filter_map { |id, row| removed_clause(row) unless now.key?(id) }
        kept + removed
      end

      def changed_clause(row, prior)
        status = clause_status(row, prior)
        return if status == "unchanged"

        clause_entry_row(row, prior, status)
      end

      def clause_status(row, prior)
        return "added" if prior.nil?
        return "changed" if row[:body] != prior[:body]
        return "moved" if row[:section_id] != prior[:section_id] || row[:index] != prior[:index]

        "unchanged"
      end

      def index_manifest_sections(previous)
        previous.each_with_index.to_h do |row, index|
          [row["recording_id"].to_s, { index: index, heading: row["heading"].to_s }]
        end
      end

      def index_clauses(current)
        current.each_with_object({}) do |section, map|
          section.clauses.each_with_index do |clause, index|
            map[clause.id.to_s] = clause_row(clause, section.id.to_s, index)
          end
        end
      end

      def index_manifest_clauses(previous)
        previous.each_with_object({}) do |section, map|
          Array(section["clauses"]).each_with_index do |clause, index|
            map[clause["recording_id"].to_s] = {
              id: clause["recording_id"].to_s,
              index: index, body: clause["body"].to_s, section_id: section["recording_id"].to_s,
              number: "#{display_number(section_index(previous, section))}.#{index + 1}"
            }
          end
        end
      end

      def section_index(previous, section)
        previous.index { |row| row["recording_id"].to_s == section["recording_id"].to_s }
      end

      def clause_row(clause, section_id, index)
        { index: index, body: clause.body.to_s, section_id: section_id, number: clause.number, id: clause.id.to_s }
      end

      def section_entry(section, status, previous_number: nil, previous_heading: nil)
        Entry.new(
          kind: "section", status: status, id: section.id.to_s, number: section.number,
          previous_number: previous_number, heading: section.heading, previous_heading: previous_heading
        )
      end

      def removed_section(row, index)
        Entry.new(
          kind: "section", status: "removed", id: row["recording_id"].to_s,
          previous_number: display_number(index), previous_heading: row["heading"].to_s, heading: row["heading"].to_s
        )
      end

      def clause_entry(clause, section, status)
        Entry.new(
          kind: "clause", status: status, id: clause.id.to_s, number: clause.number,
          body: clause.body, section_id: section.id.to_s
        )
      end

      def clause_entry_row(row, prior, status)
        Entry.new(
          kind: "clause", status: status, id: row[:id], number: row[:number],
          previous_number: prior && prior[:number], body: row[:body], previous_body: prior && prior[:body],
          section_id: row[:section_id], previous_section_id: prior && prior[:section_id]
        )
      end

      def removed_clause(row)
        Entry.new(
          kind: "clause", status: "removed", id: row[:id] || row["recording_id"].to_s,
          previous_number: row[:number], previous_body: row[:body], body: row[:body],
          previous_section_id: row[:section_id]
        )
      end

      def display_number(index)
        return if index.nil?

        (index + 1).to_s
      end
    end
  end
end
