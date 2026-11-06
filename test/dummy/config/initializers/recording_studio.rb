# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [
    "AdminRoot",
    "Workspace",
    "Folder",
    "Page",
    "RecordingStudioTermsAndConditions::Terms",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioPublishable::Publishable",
    "RecordingStudioAttachable::Attachment"
  ]

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Shown in the shared default layout title fallback.
  config.app_name = "Addon Template" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Core 6.5 fails closed without a write authorizer. Dummy uses Accessible.
  # AccessCreationContext may allow RecordingStudio::Access rows only.
  # Access writes outside that context need Accessible :admin on the root.
  # Every other write needs Accessible :edit on the root. No identity allow.
  config.authorize_write = lambda { |actor:, root_recording:, recordable:, **|
    if defined?(RecordingStudioAccessible::AccessCreationContext) &&
       RecordingStudioAccessible::AccessCreationContext.allowed? &&
       defined?(RecordingStudio::Access) &&
       recordable.is_a?(RecordingStudio::Access)
      next true
    end

    next false unless defined?(RecordingStudioAccessible)
    next false unless root_recording

    role = if defined?(RecordingStudio::Access) && recordable.is_a?(RecordingStudio::Access)
             :admin
           else
             :edit
           end

    RecordingStudioAccessible.authorized?(
      actor: actor,
      recording: root_recording,
      role: role
    )
  }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
