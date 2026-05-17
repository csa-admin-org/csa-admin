import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input"]

  get originalValue() {
    return this.inputTarget.defaultValue
  }

  submit() {
    if (this.inputTarget.value !== this.originalValue) {
      this.formTarget.requestSubmit()
    } else {
      this.inputTarget.value = this.originalValue
    }
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.inputTarget.blur()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.inputTarget.value = this.originalValue
      this.inputTarget.blur()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.inputTarget.value = Math.max(0, parseInt(this.inputTarget.value || 0) + 1)
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.inputTarget.value = Math.max(0, parseInt(this.inputTarget.value || 0) - 1)
    }
  }
}
