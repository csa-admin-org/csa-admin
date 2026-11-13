import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"
import { nextQuantity, normalizedQuantity } from "controllers/members/quantity_step"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  initialize() {
    this.inputChanged = debounce(250, this.inputChanged)
  }

  increment(event) {
    this.step(1, event)
  }

  decrement(event) {
    this.step(-1, event)
  }

  normalize() {
    const input = this.inputTarget
    const next = normalizedQuantity(input.value, {
      step: input.step,
      min: input.min,
      max: input.max
    })
    if (String(next) === input.value) return

    input.value = next
    this.inputChanged()
  }

  step(delta, event) {
    this.normalize()
    const current = Number(this.inputTarget.value)
    if (Number.isNaN(current)) {
      event.preventDefault()
      return
    }

    let next = nextQuantity(current, delta, {
      step: this.inputTarget.step,
      max: this.inputTarget.max
    })
    if (next === current) {
      event.preventDefault()
      return
    }
    if (next < 0) next = 0

    this.inputTarget.value = next
    this.inputChanged()
    event.preventDefault()
  }

  inputChanged() {
    var event = new Event("change", {
      bubbles: true,
      cancelable: true
    })
    this.inputTarget.dispatchEvent(event)
  }
}
