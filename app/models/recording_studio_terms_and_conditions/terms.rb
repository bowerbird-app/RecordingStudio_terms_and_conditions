# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Terms < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_terms"

    DEFAULT_CATEGORY = "terms"
    CATEGORIES = %w[terms privacy usage].freeze
    CATEGORY_LABELS = {
      "terms" => "Terms",
      "privacy" => "Privacy",
      "usage" => "Usage"
    }.freeze

    recording_studio_recordable label: "Terms",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    attr_accessor :category_scope_root_recording, :category_scope_recording

    attribute :category, :string, default: DEFAULT_CATEGORY

    before_validation :normalize_category
    validates :title, :body, presence: true
    validates :category, inclusion: { in: CATEGORIES }
    validate :category_unique_in_workspace, if: :category_scope_root_recording

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

    def self.category_select_options
      CATEGORY_LABELS.map { |value, label| [label, value] }
    end

    def self.normalize_category(value)
      value.to_s.presence || DEFAULT_CATEGORY
    end

    def category_label
      CATEGORY_LABELS.fetch(category, category)
    end

    def initialize_dup(other)
      super
      recording = RecordingStudio::Recording.find_by(
        recordable_type: self.class.name,
        recordable_id: other.id,
        trashed_at: nil
      )
      self.category_scope_recording = recording
      self.category_scope_root_recording = recording&.root_recording || recording
    end

    private

    def normalize_category
      self.category = self.class.normalize_category(category)
    end

    def category_unique_in_workspace
      conflict = sibling_terms_recordings.find do |recording|
        next if category_scope_recording && recording.id == category_scope_recording.id

        recording.recordable&.category == category
      end
      return if conflict.blank?

      errors.add(:category, "This workspace already has #{category_label}.")
    end

    def sibling_terms_recordings
      root = category_scope_root_recording
      root_id = root.parent_recording_id.blank? ? root.id : root.root_recording_id
      RecordingStudio::Recording.where(
        recordable_type: self.class.name,
        trashed_at: nil,
        root_recording_id: root_id
      ).includes(:recordable)
    end
  end
end
