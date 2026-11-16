# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # Outline release moves sections. Moveable's built-in check looks for an
  # Accessible grant on the recording. The shared library cannot hold one.
  # A person who can edit the admin root may move recordings in that library.
  # Anything outside the library falls through to the host hook, then built-in access.
  module LibraryMoves
    module_function

    def install!
      return if @installed
      return unless defined?(RecordingStudio::Moveable)

      @installed = true
      config = RecordingStudio::Moveable.configuration
      previous = config.authorization_hook if config.authorization_hook_set?
      config.authorization_hook = ->(**kwargs) { decide(previous, **kwargs) }
    end

    def decide(previous, actor:, source:, destination:, **rest)
      return true if library_tree?(source) && staff?(actor)
      return previous.call(actor:, source:, destination:, **rest) if previous

      nil
    end

    def library_tree?(recording)
      recording&.root_recording&.recordable_type == Library.name
    end

    def staff?(actor)
      return false if actor.blank?
      return false unless defined?(RecordingStudioAccessible)
      return false unless RecordingStudioAccessible.respond_to?(:admin_root)

      admin_root = RecordingStudioAccessible.admin_root
      return false if admin_root.blank?

      RecordingStudioAccessible.authorized?(actor: actor, recording: admin_root, role: :edit)
    end
  end
end
