# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  # A publish of a Terms document that already has an outline is a release.
  module OutlinePublish
    LATCH = :recording_studio_terms_outline_publish
    FLAG = :recording_studio_terms_outline_releasing

    class << self
      def install!
        return unless defined?(RecordingStudioPublishable)
        return if RecordingStudioPublishable.configuration.hooks.registered?(LATCH)

        RecordingStudioPublishable.configuration.hooks.on(LATCH) { true }
        RecordingStudioPublishable.configuration.hooks.around_service do |service, block|
          publish_through_release(service, block)
        end
      end

      def publish_through_release(service, block)
        return block.call unless release_instead?(service)

        released = Outline.release(parent_of(service), actor: service.send(:actor))
        child = released.publishable_child_recording
        ::RecordingStudio::Services::BaseService::Result.new(success: true, value: child)
      end

      def releasing
        previous = Thread.current[FLAG]
        Thread.current[FLAG] = true
        yield
      ensure
        Thread.current[FLAG] = previous
      end

      private

      def release_instead?(service)
        return false if Thread.current[FLAG]
        return false unless publishing_terms?(service)

        parent = parent_of(service)
        Outline.sections(parent).any? && Outline.unreleased?(parent)
      end

      def publishing_terms?(service)
        update = RecordingStudioPublishable::Services::Publishables::Update
        service.is_a?(update) && parent_of(service)&.recordable_type == Terms.name && publishing?(service)
      end

      def publishing?(service)
        service.send(:attributes).to_h.symbolize_keys[:status].to_s == "published"
      end

      def parent_of(service)
        service.send(:parent_recording)
      end
    end
  end
end
