import { Controller } from "@hotwired/stimulus"

// Optional clickwrap gate: Agree stays disabled until the end sentinel is visible.
export default class extends Controller {
  static targets = ["end", "agree"]

  connect() {
    this.lockAgree()
    if (!("IntersectionObserver" in window) || !this.hasEndTarget) return

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

  disconnect() {
    if (this.observer) this.observer.disconnect()
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
