import { Controller } from "@hotwired/stimulus"

function shouldLockAgree(canObserve, endVisible) {
  return canObserve === true && endVisible !== true
}

function elementIsInViewport(element, viewportHeight) {
  if (!element || typeof element.getBoundingClientRect !== "function") return false

  const rect = element.getBoundingClientRect()
  return rect.bottom > 0 && rect.top < viewportHeight
}

// Optional clickwrap gate: Agree stays disabled until the end sentinel is visible.
// Missing IntersectionObserver must not deadlock Agree. The checkbox is still required.
export default class extends Controller {
  static targets = ["end", "agree"]

  connect() {
    const canObserve = this.hasEndTarget && "IntersectionObserver" in window
    const visible = canObserve && elementIsInViewport(this.endTarget, this.viewportHeight())

    if (!shouldLockAgree(canObserve, visible)) {
      this.unlockAgree()
      return
    }

    this.lockAgree()
    this.observeEnd()
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  observeEnd() {
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          this.unlockAgree()
          this.observer.disconnect()
        }
      },
      { threshold: 0 }
    )
    this.observer.observe(this.endTarget)
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
