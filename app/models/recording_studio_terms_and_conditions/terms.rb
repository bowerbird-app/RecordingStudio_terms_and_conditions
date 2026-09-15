# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Terms < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_terms"

    DEFAULT_KIND = "terms"
    KINDS = %w[terms privacy usage].freeze
    KIND_LABELS = {
      "terms" => "Terms",
      "privacy" => "Privacy",
      "usage" => "Usage"
    }.freeze

    recording_studio_recordable label: "Terms",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    attr_accessor :kind_scope_root_recording, :kind_scope_recording

    attribute :kind, :string, default: DEFAULT_KIND

    before_validation :normalize_kind
    validates :title, :body, presence: true
    validates :kind, inclusion: { in: KINDS }
    validate :kind_unique_in_workspace, if: :kind_scope_root_recording

    if defined?(RecordingStudio::Capabilities::Publishable)
      include RecordingStudio::Capabilities::Publishable.to(
        public_controller: "recording_studio_terms_and_conditions/published_terms",
        public_action: :show,
        public_layout: "recording_studio/default_layout",
        path: "/terms/:uuid/:slug",
        schedule: true,
        seo: false
      )
    end

    def self.kind_select_options
      KIND_LABELS.map { |value, label| [label, value] }
    end

    def self.normalize_kind(value)
      value.to_s.presence || DEFAULT_KIND
    end

    def kind_label
      KIND_LABELS.fetch(kind, kind)
    end

    def initialize_dup(other)
      super
      recording = RecordingStudio::Recording.find_by(
        recordable_type: self.class.name,
        recordable_id: other.id,
        trashed_at: nil
      )
      self.kind_scope_recording = recording
      self.kind_scope_root_recording = recording&.root_recording || recording
    end

    private

    def normalize_kind
      self.kind = self.class.normalize_kind(kind)
    end

    def kind_unique_in_workspace
      conflict = sibling_terms_recordings.find do |recording|
        next if kind_scope_recording && recording.id == kind_scope_recording.id

        recording.recordable&.kind == kind
      end
      return if conflict.blank?

      errors.add(:kind, "This workspace already has #{kind_label}.")
    end

    def sibling_terms_recordings
      root = kind_scope_root_recording
      root_id = root.parent_recording_id.blank? ? root.id : root.root_recording_id
      RecordingStudio::Recording.where(
        recordable_type: self.class.name,
        trashed_at: nil,
        root_recording_id: root_id
      ).includes(:recordable)
    end
  end
end
