import { Controller } from "@hotwired/stimulus"

// Shows only the fields for the chosen decision (taken or skipped). Without
// JavaScript both groups stay visible and the server ignores the other one.
// The fade-in comes from CSS (.motion-swap with @starting-style).
export default class extends Controller {
  static targets = ["taken", "skipped"]

  connect() {
    this.toggle()
  }

  toggle() {
    const skipped = this.element.querySelector("input[name='journal_trade[status]']:checked")?.value === "skipped"
    this.takenTarget.hidden = skipped
    this.skippedTarget.hidden = !skipped
  }
}
