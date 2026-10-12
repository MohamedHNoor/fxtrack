import { Controller } from "@hotwired/stimulus"

// Mobile navigation drawer built on a modal <dialog>, which supplies the focus
// trap, Escape handling and inert page background.
export default class extends Controller {
  static targets = ["button", "dialog"]

  disconnect() {
    document.documentElement.classList.remove("overflow-hidden")
  }

  open() {
    this.dialogTarget.showModal()
    document.documentElement.classList.add("overflow-hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    requestAnimationFrame(() => this.dialogTarget.classList.add("is-open"))
  }

  close() {
    if (!this.dialogTarget.open) return
    document.documentElement.classList.remove("overflow-hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.dialogTarget.classList.remove("is-open")
    if (this.reducedMotion) return this.finishClose()
    // Link transitions bubble up too; wait for the panel's own slide to end.
    const onEnd = (event) => {
      if (event.target !== this.dialogTarget || event.propertyName !== "transform") return
      this.dialogTarget.removeEventListener("transitionend", onEnd)
      this.finishClose()
    }
    this.dialogTarget.addEventListener("transitionend", onEnd)
  }

  // Escape fires "cancel"; animate the close instead of the instant default.
  cancel(event) {
    event.preventDefault()
    this.close()
  }

  // Clicks on the dialog element itself land on the backdrop area.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  finishClose() {
    this.dialogTarget.close()
    this.buttonTarget.focus()
  }

  get reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
