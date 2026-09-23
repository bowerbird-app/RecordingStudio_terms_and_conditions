# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Terms < ApplicationRecord
    self.table_name = "recording_studio_terms_and_conditions_terms"

    DEFAULT_KIND = "terms_and_condition"
    KIND_TERMS = "terms_and_condition"
    KIND_PRIVACY = "privacy_policy"
    KINDS = [KIND_TERMS, KIND_PRIVACY].freeze
    KIND_LABELS = {
      KIND_TERMS => "Terms and Conditions",
      KIND_PRIVACY => "Privacy Policy"
    }.freeze
    PUBLIC_PATHS = {
      KIND_TERMS => "/terms/:uuid/:slug",
      KIND_PRIVACY => "/privacy/:uuid/:slug"
    }.freeze

    recording_studio_recordable label: "Terms",
                                root: false,
                                allowed_parent_types: ["Workspace"]

    attribute :kind, :string, default: DEFAULT_KIND

    before_validation :normalize_kind
    validates :title, :body, presence: true
    validates :kind, inclusion: { in: KINDS }

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

    def self.kind_label_for(value)
      KIND_LABELS.fetch(normalize_kind(value), normalize_kind(value))
    end

    def kind_label
      self.class.kind_label_for(kind)
    end

    def privacy_policy?
      kind == KIND_PRIVACY
    end

    def terms_and_condition?
      kind == KIND_TERMS
    end

    def public_path_template
      PUBLIC_PATHS.fetch(kind, PUBLIC_PATHS.fetch(DEFAULT_KIND))
    end

    def published_url
      url = super
      return url if url.blank? || !privacy_policy?

      url.sub("/terms/", "/privacy/")
    end

    private

    def normalize_kind
      self.kind = self.class.normalize_kind(kind)
    end
  end
end
