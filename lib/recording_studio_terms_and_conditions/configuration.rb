# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  class Configuration
    attr_accessor :mount_path
    attr_reader :hooks, :layout, :require_scroll_to_end, :capture_request_provenance,
                :gate_exempt_controllers, :actor_name_search

    DEFAULT_GATE_EXEMPT_CONTROLLERS = %w[
      recording_studio_terms_and_conditions/acceptances
      recording_studio_terms_and_conditions/admin
      recording_studio_terms_and_conditions/published_terms
      agree_helpers
      recording_studio_publishable
      recording_studio_admin
      recording_studio_accessible
      recording_studio_root_switchable
      devise
      rails/health
    ].freeze

    def initialize
      @mount_path = "/recording_studio_terms_and_conditions"
      @app_name = ""
      @layout = nil
      @require_scroll_to_end = false
      @capture_request_provenance = false
      @gate_exempt_controllers = DEFAULT_GATE_EXEMPT_CONTROLLERS.dup
      @actor_name_search = nil
      @hooks = RecordingStudio::Hooks.new
    end

    def layout=(value)
      @layout = RecordingStudio::Layout.accept(value)
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

    def gate_exempt_controllers=(value)
      @gate_exempt_controllers = Array(value).map { |name| name.to_s.strip }.reject(&:empty?)
    end

    def actor_name_search=(value)
      raise ArgumentError, "actor_name_search must be a callable" if value && !value.respond_to?(:call)

      @actor_name_search = value
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
    rescue ArgumentError, NameError
      nil
    end
  end
end
