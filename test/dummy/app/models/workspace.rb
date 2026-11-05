class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  include RecordingStudio::Capabilities::Example.to(label: "dummy workspace")
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: [ "image/*", "application/pdf", "text/plain" ],
    max_file_size: 25.megabytes,
    enabled_attachment_kinds: %i[ image file ]
  )
  # Attachable 0.22 dropped ImageLibrary. Dummy Workspace still opts into
  # :image_library so host declaration tests keep their existing assertions.
  RecordingStudio.enable_capability(:image_library, on: self)
end
