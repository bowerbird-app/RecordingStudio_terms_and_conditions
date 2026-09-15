# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Configuration
    attr_accessor :mount_path
    attr_reader :hooks, :require_scroll_to_end, :capture_request_provenance, :required_kinds

    def initialize
      @mount_path = "/recording_studio_terms_and_conditions"
      @require_scroll_to_end = false
      @capture_request_provenance = false
      @required_kinds = nil
      @hooks = RecordingStudio::Hooks.new
    end

    def require_scroll_to_end=(value)
      @require_scroll_to_end = self.class.flag?(value)
    end

    def capture_request_provenance=(value)
      @capture_request_provenance = self.class.flag?(value)
    end

    def required_kinds=(value)
      @required_kinds = self.class.kinds_list(value)
    end

    def to_h
      {
        mount_path: mount_path,
        require_scroll_to_end: require_scroll_to_end,
        capture_request_provenance: capture_request_provenance,
        required_kinds: required_kinds,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end

    def self.flag?(value)
      value == true || value.to_s.casecmp("true").zero? || value.to_s == "1"
    end

    def self.kinds_list(value)
      return if value.nil?

      Array(value).filter_map { |item| item.to_s.presence }.uniq
    end
  end
end
