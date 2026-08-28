import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "glyph", "grid"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.refresh()
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  close() {
    this.openValue = false
  }

  pick(event) {
    this.inputTarget.value = event.currentTarget.dataset.value
    this.refresh()
    this.close()
  }

  clear() {
    this.inputTarget.value = ""
    this.refresh()
    this.close()
  }

  paste(event) {
    const text = event.clipboardData?.getData("text")?.trim() ?? ""
    if (!text) return

    event.preventDefault()
    this.inputTarget.value = text
    this.refresh()
  }

  openValueChanged() {
    if (!this.hasGridTarget) return

    this.gridTarget.classList.toggle("is-hidden", !this.openValue)
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", this.openValue)
    }
    if (this.openValue) this.markSelected()
  }

  refresh() {
    if (!this.hasInputTarget || !this.hasButtonTarget || !this.hasGlyphTarget) return

    const value = this.inputTarget.value
    this.glyphTarget.textContent = value
    this.buttonTarget.classList.toggle("is-empty", !value)
    this.markSelected()
  }

  markSelected() {
    if (!this.hasGridTarget) return

    const current = this.inputTarget.value
    this.gridTarget.querySelectorAll("[data-value]").forEach((cell) => {
      cell.classList.toggle("is-selected", cell.dataset.value === current)
    })
  }
}
