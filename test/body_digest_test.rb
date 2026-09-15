# frozen_string_literal: true

require "digest"
require "test_helper"

class BodyDigestTest < Minitest::Test
  def test_call_prefixes_sha256_hex_of_the_live_body
    body = "Be kind. Don't be a jerk."

    assert_equal "sha256:#{Digest::SHA256.hexdigest(body)}", RecordingStudioTermsAndConditions::BodyDigest.call(body)
    assert_equal Digest::SHA256.hexdigest(body), RecordingStudioTermsAndConditions::BodyDigest.hex(body)
    assert_equal "sha256", RecordingStudioTermsAndConditions::BodyDigest::ALGORITHM
  end

  def test_empty_and_nil_bodies_are_stable
    assert_equal RecordingStudioTermsAndConditions::BodyDigest.call(""),
                 RecordingStudioTermsAndConditions::BodyDigest.call(nil)
  end
end
