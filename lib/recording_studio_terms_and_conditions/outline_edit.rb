# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Outline
    class << self
      def add_section(terms_recording, heading:, actor:)
        position = sections(terms_recording).size
        tree_root(terms_recording).record(Section, parent_recording: terms_recording, actor: actor) do |section|
          section.heading = heading.to_s
          section.position = position
        end
      end

      def edit_section(section_recording, heading:, actor:)
        revise_recordable(section_recording, actor) { |section| section.heading = heading.to_s }
      end

      def move_section(section_recording, to_index:, actor:)
        siblings = children(section_recording.parent_recording, Section.name)
        reorder(siblings, section_recording, to_index, actor)
      end

      def remove_section(section_recording, actor:)
        parent = section_recording.parent_recording
        children(section_recording, Clause.name).each { |clause| trash!(clause, actor) }
        trash!(section_recording, actor)
        compact(parent, Section.name, actor)
        section_recording
      end

      def add_clause(section_recording, body:, actor:)
        position = children(section_recording, Clause.name).size
        tree_root(section_recording).record(Clause, parent_recording: section_recording, actor: actor) do |clause|
          clause.body = body.to_s
          clause.position = position
        end
      end

      def edit_clause(clause_recording, body:, actor:)
        revise_recordable(clause_recording, actor) { |clause| clause.body = body.to_s }
      end

      def move_clause(clause_recording, to_index:, actor:, section_recording: nil)
        reparent_clause!(clause_recording, section_recording, actor) if section_recording
        siblings = children(clause_recording.parent_recording, Clause.name)
        reorder(siblings, clause_recording, to_index, actor)
      end

      def remove_clause(clause_recording, actor:)
        parent = clause_recording.parent_recording
        trash!(clause_recording, actor)
        compact(parent, Clause.name, actor)
        clause_recording
      end

      private

      def reparent_clause!(clause_recording, section_recording, actor)
        return if clause_recording.parent_recording_id == section_recording.id

        previous = clause_recording.parent_recording
        clause_recording.move_to!(new_parent: section_recording, actor: actor)
        compact(previous, Clause.name, actor)
      end

      def reorder(recordings, target, to_index, actor)
        ordered = recordings.reject { |recording| recording.id == target.id }
        ordered.insert(bounded_index(to_index, ordered.size), target)
        ordered.each_with_index { |recording, position| revise_position(recording, position, actor) }
        target
      end

      def compact(parent, type, actor)
        return if parent.nil?

        children(parent, type).each_with_index do |recording, position|
          revise_position(recording, position, actor)
        end
      end

      def revise_position(recording, position, actor)
        return recording if recording.recordable.position == position

        revise_recordable(recording, actor) { |recordable| recordable.position = position }
      end

      def revise_recordable(recording, actor, &)
        tree_root(recording).revise(recording, actor: actor, &)
      end

      def trash!(recording, actor)
        recording.log_event!(action: "trashed", actor: actor)
        recording.update!(trashed_at: Time.current)
      end

      def bounded_index(to_index, size)
        index = to_index.to_i
        return 0 if index.negative?
        return size if index > size

        index
      end
    end
  end
end
