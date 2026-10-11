import { Controller } from "@hotwired/stimulus"

// Fades elements in as they scroll into view. Elements stay visible without
// JavaScript because the hidden state is only applied after connect.
export default class extends Controller {
  static targets = ["item"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.observer = new IntersectionObserver((entries) => this.reveal(entries), { threshold: 0.15 })
    this.itemTargets.forEach((item) => {
      item.classList.add("reveal-pending")
      this.observer.observe(item)
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  reveal(entries) {
    entries.filter((entry) => entry.isIntersecting).forEach((entry) => {
      entry.target.classList.add("reveal-visible")
      this.observer.unobserve(entry.target)
    })
  }
}
