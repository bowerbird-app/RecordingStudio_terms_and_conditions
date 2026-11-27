# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [
    "AdminRoot",
    "Workspace",
    "Folder",
    "Page",
    "RecordingStudioTermsAndConditions::Library",
    "RecordingStudioTermsAndConditions::Terms",
    "RecordingStudioTermsAndConditions::Section",
    "RecordingStudioTermsAndConditions::Clause",
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

  # Core 7 fails closed without a write authorizer. Dummy uses Accessible.
  # A new root is authorized with root_recording nil. A present actor may create it.
  # AccessCreationContext may allow RecordingStudio::Access rows only.
  # Access writes outside that context need Accessible :admin on the root.
  # A person may record their own Profile on the shared People root. Users writes
  # that row during password sign-up, before the person has edit on People.
  # Every other write needs Accessible :edit on the root.
  config.authorize_write = lambda { |actor:, root_recording:, recordable:, **|
    if defined?(RecordingStudioAccessible::AccessCreationContext) &&
       RecordingStudioAccessible::AccessCreationContext.allowed? &&
       defined?(RecordingStudio::Access) &&
       recordable.is_a?(RecordingStudio::Access)
      next true
    end

    next actor.present? if root_recording.nil?

    if defined?(RecordingStudioUser::Profile) &&
       recordable.is_a?(RecordingStudioUser::Profile) &&
       actor.respond_to?(:id) &&
       recordable.user_id.present? &&
       recordable.user_id == actor.id &&
       root_recording.recordable_type == "RecordingStudioUser::People"
      next true
    end

    # Provisioning records the client, credential, and access token on the
    # access point. The client is the write actor. Operations clients on
    # AdminRoot often hold :view at that moment, which is not :edit.
    if defined?(RecordingStudioApi::ApiClient) && actor.is_a?(RecordingStudioApi::ApiClient) && (
         recordable.is_a?(RecordingStudioApi::ApiClient) ||
         (defined?(RecordingStudioApi::ApiCredential) && recordable.is_a?(RecordingStudioApi::ApiCredential)) ||
         (defined?(RecordingStudioApi::ApiAccessToken) && recordable.is_a?(RecordingStudioApi::ApiAccessToken))
       )
      next true
    end

    next false unless defined?(RecordingStudioAccessible)

    if root_recording.recordable_type == "RecordingStudioTermsAndConditions::Library"
      admin = RecordingStudioAccessible.admin_root if RecordingStudioAccessible.respond_to?(:admin_root)
      next false if actor.blank? || admin.blank?

      next RecordingStudioAccessible.authorized?(actor: actor, recording: admin, role: :edit)
    end

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
