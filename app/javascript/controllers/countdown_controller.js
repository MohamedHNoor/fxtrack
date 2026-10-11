import { Controller } from "@hotwired/stimulus"

// Counts down to a server-provided expiry. The server status stays the
// authority on validity; at zero the page asks for a refresh.
export default class extends Controller {
  static values = { expiresAt: String }

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const seconds = Math.max(0, Math.floor((Date.parse(this.expiresAtValue) - Date.now()) / 1000))
    this.element.textContent = seconds > 0 ? `${Math.floor(seconds / 60)}m ${String(seconds % 60).padStart(2, "0")}s left` : "Expired, refresh for status"
    if (seconds === 0) clearInterval(this.timer)
  }
}
