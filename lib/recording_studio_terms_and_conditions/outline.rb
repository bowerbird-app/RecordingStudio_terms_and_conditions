# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # The live outline of a Terms document. Numbers come from order. Ids stay put.
  module Outline
    class Missing < StandardError; end

    Node = Struct.new(:recording, :number, :heading, :body, :clauses, keyword_init: true) do
      def id
        recording.id
      end

      def snapshot_id
        recording.recordable_id
      end

      def position
        recording.recordable.position.to_i
      end
    end

    class << self
      def sections(terms_recording)
        children(terms_recording, Section.name).map.with_index(1) do |recording, number|
          Node.new(
            recording: recording,
            number: number.to_s,
            heading: recording.recordable.heading.to_s,
            clauses: clause_nodes(recording, number)
          )
        end
      end

      def find_section!(terms_recording, id)
        found = sections(terms_recording).find { |section| section.id.to_s == id.to_s }
        raise Missing, "Section not found" if found.nil?

        found
      end

      def find_clause!(terms_recording, id)
        found = sections(terms_recording).flat_map(&:clauses).find { |clause| clause.id.to_s == id.to_s }
        raise Missing, "Clause not found" if found.nil?

        found
      end

      def children(parent, type)
        tree_root(parent).child_recordings_of(parent, type: type)
                         .where(trashed_at: nil)
                         .includes(:recordable)
                         .sort_by { |recording| child_sort_key(recording) }
      end

      def live?(recording)
        recording.respond_to?(:currently_published?) && recording.currently_published?
      end

      def manifest_payload(terms_recording)
        { "sections" => sections(terms_recording).map { |section| section_payload(section) } }
      end

      def manifest_sections(terms_recording)
        raw = terms_recording.recordable&.release_manifest
        return if raw.blank?

        data = raw.respond_to?(:deep_stringify_keys) ? raw.deep_stringify_keys : raw
        Array(data["sections"])
      end

      private

      def clause_nodes(section_recording, section_number)
        children(section_recording, Clause.name).map.with_index(1) do |recording, index|
          Node.new(
            recording: recording,
            number: "#{section_number}.#{index}",
            body: recording.recordable.body.to_s,
            clauses: []
          )
        end
      end

      def tree_root(recording)
        recording.root_recording || recording
      end

      def child_sort_key(recording)
        position = recording.recordable.respond_to?(:position) ? recording.recordable.position.to_i : 0
        [position, recording.created_at.to_f, recording.id.to_s]
      end

      def section_payload(section)
        {
          "recording_id" => section.id.to_s,
          "snapshot_id" => section.snapshot_id.to_s,
          "position" => section.position,
          "heading" => section.heading,
          "clauses" => section.clauses.map { |clause| clause_payload(clause) }
        }
      end

      def clause_payload(clause)
        {
          "recording_id" => clause.id.to_s,
          "snapshot_id" => clause.snapshot_id.to_s,
          "position" => clause.position,
          "body" => clause.body
        }
      end
    end
  end
end
