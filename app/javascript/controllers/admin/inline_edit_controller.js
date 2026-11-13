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

  stepInput(direction) {
    const step = Number(this.inputTarget.step)
    const amount = Number.isFinite(step) && step > 0 ? step : 1
    const current = Number(this.inputTarget.value)
    const base = Number.isFinite(current) ? current : 0
    const places = (String(amount).split(".")[1] || "").length
    const next = Math.max(0, base + direction * amount)
    this.inputTarget.value = places ? next.toFixed(places) : String(Math.round(next))
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
      this.stepInput(1)
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.stepInput(-1)
    }
  }
}
