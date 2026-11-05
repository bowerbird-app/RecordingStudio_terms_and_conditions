class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  include RecordingStudio::Capabilities::Example.to(label: "dummy workspace")
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: [ "image/*", "application/pdf", "text/plain" ],
    max_file_size: 25.megabytes,
    enabled_attachment_kinds: %i[ image file ]
  )
end
