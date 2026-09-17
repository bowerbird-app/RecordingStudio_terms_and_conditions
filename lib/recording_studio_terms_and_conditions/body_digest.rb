# frozen_string_literal: true

require "digest"

module RecordingStudioTermsAndConditions
  # SHA-256 digest of the live Terms body at accept time.
  class BodyDigest
    ALGORITHM = "sha256"

    def self.hex(body)
      Digest::SHA256.hexdigest(body.to_s)
    end

    def self.call(body)
      "#{ALGORITHM}:#{hex(body)}"
    end
  end
end
