# frozen_string_literal: true

require "json"
require "open3"
require "test_helper"

class ScrollToEndControllerTest < Minitest::Test
  GATE = File.expand_path(
    "../app/javascript/recording_studio_terms_and_conditions/controllers/scroll_to_end_gate.js",
    __dir__
  )
  CONTROLLER = File.expand_path(
    "../app/javascript/recording_studio_terms_and_conditions/controllers/scroll_to_end_controller.js",
    __dir__
  )

  def test_missing_intersection_observer_does_not_lock_agree
    refute gate_js("shouldLockAgree(false, false)")
    refute gate_js("shouldLockAgree(false, true)")
  end

  def test_already_visible_sentinel_does_not_lock_agree
    refute gate_js("shouldLockAgree(true, true)")
    assert gate_js("shouldLockAgree(true, false)")
  end

  def test_already_visible_element_unlocks
    assert gate_js("elementIsInViewport({ getBoundingClientRect: () => ({ top: 10, bottom: 24 }) }, 100)")
    refute gate_js("elementIsInViewport({ getBoundingClientRect: () => ({ top: 800, bottom: 820 }) }, 100)")
    refute gate_js("elementIsInViewport(null, 100)")
  end

  def test_controller_unlocks_when_observer_is_missing_or_sentinel_is_visible
    source = File.read(CONTROLLER)

    assert_includes source, 'import { shouldLockAgree, elementIsInViewport } from "./scroll_to_end_gate"'
    assert_includes source, 'this.hasEndTarget && "IntersectionObserver" in window'
    assert_includes source, "if (!shouldLockAgree(canObserve, visible))"
    assert_includes source, "this.unlockAgree()"
  end

  private

  def gate_js(expression)
    href = "file://#{GATE}"
    stdout, stderr, status = Open3.capture3(
      "node",
      "--input-type=module",
      "-e",
      <<~JS
        import { shouldLockAgree, elementIsInViewport } from #{href.to_json};
        console.log(JSON.stringify(#{expression}));
      JS
    )

    raise "node gate failed: #{stderr}" unless status.success?

    JSON.parse(stdout)
  end
end
