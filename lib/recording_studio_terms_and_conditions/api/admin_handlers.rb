# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Api
    module AdminGate
      module_function

      def authorize!(context, role)
        return if Access.authorized_on_admin_root?(context, role)

        raise RecordingStudioApi::AuthorizationError, "Admin access is required"
      end
    end

    module AdminPayload
      module_function

      def document(recording)
        {
          id: recording.id.to_s,
          title: recording.recordable.title,
          kind: recording.recordable.kind,
          live: Outline.live?(recording),
          version_id: recording.recordable_id.to_s,
          unreleased_changes: Outline.unreleased?(recording)
        }
      end

      def outline(recording)
        document(recording).merge(sections: Outline.sections(recording).map { |section| section_hash(section) })
      end

      def section_hash(section)
        {
          id: section.id.to_s,
          number: section.number,
          heading: section.heading,
          clauses: section.clauses.map { |clause| clause_hash(clause) }
        }
      end

      def clause_hash(clause)
        { id: clause.id.to_s, number: clause.number, body: clause.body }
      end

      def change_hash(change) # rubocop:disable Metrics/MethodLength
        {
          kind: change.kind,
          status: change.status,
          id: change.id,
          number: change.number,
          previous_number: change.previous_number,
          heading: change.heading,
          previous_heading: change.previous_heading,
          body: change.body,
          previous_body: change.previous_body,
          section_id: change.section_id,
          previous_section_id: change.previous_section_id
        }.compact
      end

      def release_hash(recording, released:)
        document(recording).merge(released: released, body: recording.recordable.body)
      end
    end

    class Documents
      def self.call(context)
        AdminGate.authorize!(context, :view)
        root = context.recording
        raise RecordingStudioApi::NotFoundError, "Workspace not found" unless root.recordable_type == "Workspace"

        kind = context.params[:kind].presence
        documents = Outline.children(root, Terms.name).map { |recording| AdminPayload.document(recording) }
        documents.select! { |document| document[:kind] == kind } if kind
        { documents: documents }
      end
    end

    class OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :view)
        { outline: AdminPayload.outline(terms!(context)) }
      end

      def self.terms!(context)
        recording = context.recording
        return recording if recording.recordable_type == Terms.name

        raise RecordingStudioApi::NotFoundError, "Terms not found"
      end
    end

    class SectionAction < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :view)
        section = find_section(context)
        { section: AdminPayload.section_hash(section) }
      end
    end

    class ClauseAction < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :view)
        clause = find_clause(context)
        { clause: AdminPayload.clause_hash(clause).merge(section_id: clause.recording.parent_recording_id.to_s) }
      end
    end

    class Changes < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :view)
        recording = terms!(context)
        {
          unreleased_changes: Outline.unreleased?(recording),
          changes: Outline.changes(recording).map { |change| AdminPayload.change_hash(change) }
        }
      end
    end

    class Preview < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :view)
        { preview: Outline.preview(terms!(context), title: context.params[:title]) }
      end
    end

    class AddSection < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        recording = Outline.add_section(terms!(context), heading: context.params[:heading], actor: actor(context))
        { section: located_section(context, recording.id) }
      end
    end

    class EditSection < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        section = find_section(context)
        Outline.edit_section(section.recording, heading: context.params[:heading], actor: actor(context))
        { section: located_section(context, section.id) }
      end
    end

    class MoveSection < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        section = find_section(context)
        Outline.move_section(section.recording, to_index: context.params[:to_index], actor: actor(context))
        { section: located_section(context, section.id) }
      end
    end

    class RemoveSection < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        section = find_section(context)
        Outline.remove_section(section.recording, actor: actor(context))
        { removed: true, id: section.id.to_s }
      end
    end

    class AddClause < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        section = find_section(context)
        recording = Outline.add_clause(section.recording, body: context.params[:body], actor: actor(context))
        { clause: located_clause(context, recording.id) }
      end
    end

    class EditClause < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        clause = find_clause(context)
        Outline.edit_clause(clause.recording, body: context.params[:body], actor: actor(context))
        { clause: located_clause(context, clause.id) }
      end
    end

    class MoveClause < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        clause = find_clause(context)
        destination = section_recording(context)
        Outline.move_clause(
          clause.recording,
          to_index: context.params[:to_index],
          actor: actor(context),
          section_recording: destination
        )
        { clause: located_clause(context, clause.id) }
      end
    end

    class RemoveClause < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        clause = find_clause(context)
        Outline.remove_clause(clause.recording, actor: actor(context))
        { removed: true, id: clause.id.to_s }
      end
    end

    class Release < OutlineAction
      def self.call(context)
        AdminGate.authorize!(context, :edit)
        recording = terms!(context)
        before = [recording.id, recording.recordable_id]
        released = Outline.release(recording, actor: actor(context), title: context.params[:title])
        changed = before != [released.id, released.recordable_id]
        { release: AdminPayload.release_hash(released, released: changed) }
      end
    end

    class OutlineAction
      def self.actor(context)
        Access.actor_for(context)
      end

      def self.find_section(context)
        Outline.find_section!(terms!(context), context.params[:section_id])
      rescue Outline::Missing
        raise RecordingStudioApi::NotFoundError, "Section not found"
      end

      def self.find_clause(context)
        Outline.find_clause!(terms!(context), context.params[:clause_id])
      rescue Outline::Missing
        raise RecordingStudioApi::NotFoundError, "Clause not found"
      end

      def self.section_recording(context)
        return if context.params[:section_id].blank?

        find_section(context).recording
      end

      def self.located_section(context, id)
        AdminPayload.section_hash(Outline.find_section!(terms!(context), id))
      end

      def self.located_clause(context, id)
        clause = Outline.find_clause!(terms!(context), id)
        AdminPayload.clause_hash(clause).merge(section_id: clause.recording.parent_recording_id.to_s)
      end
    end
  end
end
