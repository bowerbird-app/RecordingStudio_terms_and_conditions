import { Controller } from "@hotwired/stimulus"

function shouldLockAgree(canObserve, endVisible) {
  return canObserve === true && endVisible !== true
}

function elementIsInViewport(element, viewportHeight) {
  if (!element || typeof element.getBoundingClientRect !== "function") return false

  const rect = element.getBoundingClientRect()
  return rect.bottom > 0 && rect.top < viewportHeight
}

function sentinelIsObservable(element) {
  if (!element) return false
  if (element.hidden) return false
  if (typeof element.closest === "function" && element.closest("[hidden]")) return false

  return true
}

// Optional clickwrap gate: Agree stays disabled until the end sentinel is visible.
// A sentinel inside a closed collapse cannot be observed, so Agree stays enabled.
// Missing IntersectionObserver must not deadlock Agree. The checkbox is still required.
export default class extends Controller {
  static targets = ["end", "agree"]

  connect() {
    this.syncAgree()
    this.watchHidden()
  }

  disconnect() {
    this.disconnectIntersection()
    if (this.hiddenObserver) this.hiddenObserver.disconnect()
  }

  syncAgree() {
    const canObserve =
      this.hasEndTarget && "IntersectionObserver" in window && sentinelIsObservable(this.endTarget)
    const visible = canObserve && elementIsInViewport(this.endTarget, this.viewportHeight())

    if (!shouldLockAgree(canObserve, visible)) {
      this.unlockAgree()
      this.disconnectIntersection()
      return
    }

    this.lockAgree()
    this.observeEnd()
  }

  watchHidden() {
    if (typeof MutationObserver !== "function") return

    this.hiddenObserver = new MutationObserver(() => this.syncAgree())
    this.hiddenObserver.observe(this.element, {
      attributes: true,
      subtree: true,
      attributeFilter: ["hidden"]
    })
  }

  observeEnd() {
    if (this.observer || !this.hasEndTarget) return

    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          this.unlockAgree()
          this.disconnectIntersection()
        }
      },
      { threshold: 0 }
    )
    this.observer.observe(this.endTarget)
  }

  disconnectIntersection() {
    if (!this.observer) return

    this.observer.disconnect()
    this.observer = null
  }

  viewportHeight() {
    return window.innerHeight || document.documentElement.clientHeight
  }

  lockAgree() {
    this.agreeTargets.forEach((button) => {
      button.disabled = true
    })
  }

  unlockAgree() {
    this.agreeTargets.forEach((button) => {
      button.disabled = false
    })
  }
}
