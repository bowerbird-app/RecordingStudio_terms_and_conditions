# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # One shared root for every Terms document. Nobody owns it.
  module LibraryRoot
    module_function

    def recording(actor: nil)
      row = Library.first
      existing = row && RecordingStudio.root_recording_for(row)
      return existing if existing

      actor = actor.presence || implicit_actor
      return if actor.blank?

      row ||= Library.create!
      RecordingStudio.root_recording_for(row) || create_recording!(row, actor)
    end

    def implicit_actor
      return unless defined?(Current)

      Current.actor
    end

    def create_recording!(row, actor)
      RecordingStudio.create_root_recording!(row, actor: actor)
    rescue ActiveRecord::RecordNotUnique
      RecordingStudio.root_recording_for(row) || raise
    end
    private_class_method :create_recording!
  end
end
