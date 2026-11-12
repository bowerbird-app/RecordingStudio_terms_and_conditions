# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    # Opt-in mixin so API capability actions can attach to a root type.
    #
    # Host models opt in with:
    #   include RecordingStudio::Capabilities::TermsAndConditions.to
    #
    # Installing this gem does not enable the mixin on any type.
    module TermsAndConditions
      def self.to(**)
        RecordingStudio::Capabilities.include_for(:terms_and_conditions, **)
      end
    end
  end
end

RecordingStudio.register_capability(
  :terms_and_conditions,
  source: RecordingStudio::Capabilities::TermsAndConditions
)
