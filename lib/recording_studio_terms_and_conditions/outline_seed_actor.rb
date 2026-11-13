# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module OutlineSeedActor
    module_function

    def resolve!
      env_actor || current_actor || configured_actor ||
        raise("Pass ACTOR_TYPE and ACTOR_ID, or set Current.actor, before seeding terms outlines")
    end

    def env_actor
      return if ENV["ACTOR_TYPE"].blank? || ENV["ACTOR_ID"].blank?

      ENV.fetch("ACTOR_TYPE").constantize.find(ENV.fetch("ACTOR_ID"))
    end

    def current_actor
      return unless defined?(Current) && Current.respond_to?(:actor)

      Current.actor.presence
    end

    def configured_actor
      actor = RecordingStudio.configuration.actor if defined?(RecordingStudio)
      resolved = actor.respond_to?(:call) ? actor.call : actor
      resolved.presence
    end
  end
end
