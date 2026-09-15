# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Configuration
    attr_accessor :api_key, :enable_feature_x, :timeout, :mount_path
    attr_reader :hooks, :require_scroll_to_end

    def initialize
      @api_key = ENV.fetch("RECORDING_STUDIO_TERMS_AND_CONDITIONS_API_KEY", nil)
      @enable_feature_x = false
      @timeout = 5
      @mount_path = "/recording_studio_terms_and_conditions"
      @require_scroll_to_end = false
      @hooks = RecordingStudio::Hooks.new
    end

    def require_scroll_to_end=(value)
      @require_scroll_to_end = ActiveModel::Type::Boolean.new.cast(value)
    end

    def to_h
      {
        api_key: api_key,
        enable_feature_x: enable_feature_x,
        timeout: timeout,
        mount_path: mount_path,
        require_scroll_to_end: require_scroll_to_end,
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
  end
end
