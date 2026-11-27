# frozen_string_literal: true

module RecordingStudioTermsAndConditions
  module Outline
    class << self
      def release(terms_recording, actor:, title: nil)
        seed_recording!(terms_recording, actor: actor)
        raise Unchanged, Copy.t("errors.unchanged") unless unreleased?(terms_recording, title: title)

        publish_release(terms_recording, actor, release_title(terms_recording, title))
      end

      private

      def publish_release(terms_recording, actor, title)
        body = assemble(terms_recording)
        manifest = manifest_payload(terms_recording)
        ActiveRecord::Base.transaction do
          recording = released_recording(terms_recording, actor, title, body, manifest)
          publish!(recording, actor, title)
          recording.reload
        end
      end

      def released_recording(terms_recording, actor, title, body, manifest)
        tree_root(terms_recording).revise(terms_recording, actor: actor) do |terms|
          assign_released_terms(terms, terms_recording, title, body, manifest)
        end
      end

      def assign_released_terms(terms, recording, title, body, manifest)
        terms.title = title
        terms.body = body
        terms.kind = recording.recordable.kind
        terms.release_manifest = manifest
      end

      def publish!(recording, actor, title)
        OutlinePublish.releasing do
          with_actor(actor) do
            slug = slug_for(recording, title)
            if live?(recording)
              RecordingStudioPublishable::Services::Publishables::Update.call(
                parent_recording: recording,
                attributes: { slug: slug, status: "draft" },
                actor: actor
              ).value!
            end
            RecordingStudioPublishable::Services::Publishables::Update.call(
              parent_recording: recording,
              attributes: { slug: slug, status: "published" },
              actor: actor
            ).value!
          end
        end
      end

      def with_actor(actor)
        previous = defined?(Current) ? Current.actor : nil
        Current.actor = previous.presence || actor if defined?(Current)
        yield
      ensure
        Current.actor = previous if defined?(Current)
      end

      def release_title(recording, title)
        title.presence || recording.recordable.title.to_s
      end

      def slug_for(recording, title)
        recording.try(:current_publishable)&.try(:slug).presence || generated_slug(title)
      end

      def generated_slug(title)
        base = title.to_s.parameterize
        base = "terms" if base.blank?
        "#{base}-#{SecureRandom.hex(4)}"
      end
    end
  end
end
