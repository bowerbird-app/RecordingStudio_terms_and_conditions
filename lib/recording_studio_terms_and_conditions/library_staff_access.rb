# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Terms is an accessible child of the shared library, the same shape as
  # Profile under People. The shared root cannot hold a grant. The first
  # writer of a document is its access owner. Other people who can edit the
  # admin root get edit on that document, so preview and outline changes work
  # for every staff member.
  module LibraryStaffAccess
    module_function

    def install!
      return if @installed

      @installed = true
      RecordingStudio.configuration.hooks.after_record { |event| grant!(event) }
    end

    def grant!(event)
      recording = created_terms(event)
      return if recording.blank?

      actor = event.actor
      return if actor.blank? || !defined?(RecordingStudioAccessible)

      bootstrap_owner!(recording, actor)
      share_with_staff!(recording, actor)
    end

    def created_terms(event)
      return unless event.action.to_s == "created"

      recording = event.recording
      return unless recording&.recordable_type == Terms.name
      return unless recording.root_recording&.recordable_type == Library.name

      recording
    end

    def bootstrap_owner!(recording, actor)
      return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :admin)

      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
      raise result.error if result.failure?
    end

    def share_with_staff!(recording, owner)
      staff_editors(owner).each do |actor|
        next if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)

        result = RecordingStudioAccessible.grant_access(
          recording: recording, actor: actor, role: :edit, manager_actor: owner
        )
        raise result.error if result.failure?
      end
    end

    def staff_editors(owner)
      return [] unless RecordingStudioAccessible.respond_to?(:admin_root)

      admin_root = RecordingStudioAccessible.admin_root
      return [] if admin_root.blank?

      RecordingStudioAccessible.actors_with_access(recording: admin_root, minimum_role: :edit).filter_map do |entry|
        entry.actor unless entry.actor.blank? || same_actor?(entry.actor, owner)
      end
    end

    def same_actor?(left, right)
      left.class.base_class == right.class.base_class && left.id == right.id
    end
  end
end
