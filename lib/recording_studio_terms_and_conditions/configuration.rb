# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Configuration
    attr_accessor :mount_path
    attr_reader :hooks, :require_scroll_to_end, :capture_request_provenance

    def initialize
      @mount_path = "/recording_studio_terms_and_conditions"
      @app_name = ""
      @require_scroll_to_end = false
      @capture_request_provenance = false
      @hooks = RecordingStudio::Hooks.new
    end

    def app_name
      configured = @app_name.to_s.strip
      return configured unless configured.empty?

      site_settings_name.to_s
    end

    def app_name=(value)
      @app_name = value.nil? ? "" : value.to_s
    end

    def require_scroll_to_end=(value)
      @require_scroll_to_end = self.class.flag?(value)
    end

    def capture_request_provenance=(value)
      @capture_request_provenance = self.class.flag?(value)
    end

    def to_h
      {
        mount_path: mount_path,
        app_name: app_name,
        require_scroll_to_end: require_scroll_to_end,
        capture_request_provenance: capture_request_provenance,
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

    private

    def site_settings_name
      return unless defined?(::RecordingStudioSiteSettings)
      return unless ::RecordingStudioSiteSettings.respond_to?(:name_for)

      method = ::RecordingStudioSiteSettings.method(:name_for)
      name = method.arity.zero? ? method.call : method.call(nil)
      name.to_s.strip.presence
    rescue ArgumentError, NoMethodError, NameError
      nil
    end
  end
end
