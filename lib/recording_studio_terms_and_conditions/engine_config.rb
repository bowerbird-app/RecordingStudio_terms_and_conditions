# frozen_string_literal: true

require "psych"

module RecordingStudioTermsAndConditions
  module EngineConfig
    YAML_ERRORS = [
      ArgumentError,
      Errno::ENOENT,
      Psych::Exception,
      RuntimeError
    ].freeze
    XCONFIG_ERRORS = [ArgumentError, NoMethodError, TypeError].freeze

    module_function

    def load!(app)
      merge_yaml!(app)
      merge_x_config!(app)
      cfg = RecordingStudioTermsAndConditions.configuration
      cfg.hooks.run(:on_configuration, cfg)
    end

    def merge_yaml!(app)
      return unless app.respond_to?(:config_for)

      yaml = read_yaml(app)
      RecordingStudioTermsAndConditions.configuration.merge!(yaml) if yaml.respond_to?(:each)
    rescue *YAML_ERRORS => e
      HandledError.log(e, "config yaml skipped")
    end

    def merge_x_config!(app)
      xcfg = x_config(app)
      return if xcfg.blank?

      if xcfg.respond_to?(:to_h)
        RecordingStudioTermsAndConditions.configuration.merge!(xcfg.to_h)
      else
        merge_each_pair!(xcfg)
      end
    end

    def merge_each_pair!(xcfg)
      hash = {}
      xcfg.each_pair { |key, value| hash[key] = value } if xcfg.respond_to?(:each_pair)
      RecordingStudioTermsAndConditions.configuration.merge!(hash) if hash.any?
    rescue *XCONFIG_ERRORS => e
      HandledError.log(e, "config.x skipped")
    end

    def read_yaml(app)
      app.config_for(:recording_studio_terms_and_conditions)
    rescue *YAML_ERRORS => e
      HandledError.log(e, "config_for skipped")
      nil
    end

    def x_config(app)
      return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_terms_and_conditions)

      app.config.x.recording_studio_terms_and_conditions
    end
  end
end
