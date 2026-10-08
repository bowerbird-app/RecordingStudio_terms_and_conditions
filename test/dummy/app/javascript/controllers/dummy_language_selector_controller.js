import { Controller } from "@hotwired/stimulus"

// Compact PageNav wrapper around recording_studio_language_selector.
// Changing the locale select submits the engine form (full page load).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
