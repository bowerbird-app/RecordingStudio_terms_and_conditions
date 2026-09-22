# frozen_string_literal: true

require "json"
require "open3"
require "test_helper"

class ScrollToEndControllerTest < Minitest::Test
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

  def test_hidden_sentinel_is_not_observable
    hidden = "{ hidden: true, closest: () => null }"
    nested = "{ hidden: false, closest: (sel) => (sel === '[hidden]' ? {} : null) }"
    visible = "{ hidden: false, closest: () => null }"

    refute gate_js("sentinelIsObservable(null)")
    refute gate_js("sentinelIsObservable(#{hidden})")
    refute gate_js("sentinelIsObservable(#{nested})")
    assert gate_js("sentinelIsObservable(#{visible})")
  end

  def test_controller_unlocks_when_observer_is_missing_or_sentinel_is_hidden
    source = File.read(CONTROLLER)

    refute_includes source, "scroll_to_end_gate"
    refute_includes source, "from \"./"
    assert_includes source, "sentinelIsObservable"
    assert_includes source, 'this.hasEndTarget && "IntersectionObserver" in window && sentinelIsObservable(this.endTarget)'
    assert_includes source, "if (!shouldLockAgree(canObserve, visible))"
    assert_includes source, "this.unlockAgree()"
    assert_includes source, "attributeFilter: [\"hidden\"]"
    assert_includes source, "this.syncAgree()"
    assert_includes source, 'this.hiddenObserver.observe(this.element'
  end

  private

  def gate_js(expression)
    source = File.read(CONTROLLER)
    helpers = source[%r{\Aimport \{ Controller \} from "@hotwired/stimulus"\n\n(.*)\n\n// Optional clickwrap}m, 1]
    raise "could not extract scroll helpers" if helpers.blank?

    stdout, stderr, status = Open3.capture3(
      "node",
      "--input-type=module",
      "-e",
      "#{helpers}\nconsole.log(JSON.stringify(#{expression}));"
    )

    raise "node gate failed: #{stderr}" unless status.success?

    JSON.parse(stdout)
  end
end
