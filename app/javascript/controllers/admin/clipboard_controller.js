import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String, copyLabel: String, copiedLabel: String }
  static targets = ["button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      return
    }

    this.buttonTarget.classList.add("is-copied")
    this.buttonTarget.setAttribute("aria-label", this.copiedLabelValue)
    this.buttonTarget.title = this.copiedLabelValue
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.reset(), 1500)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  reset() {
    if (!this.hasButtonTarget) return

    this.buttonTarget.classList.remove("is-copied")
    this.buttonTarget.setAttribute("aria-label", this.copyLabelValue)
    this.buttonTarget.title = this.copyLabelValue
  }
}
