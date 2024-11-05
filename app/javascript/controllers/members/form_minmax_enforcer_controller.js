import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  enforce(event) {
    let input = event.target
    let value = parseInt(input.value)

    let minValue = parseInt(input.getAttribute("min")) || 0
    let maxValue = parseInt(input.getAttribute("max")) || Infinity
    let step = parseInt(input.getAttribute("step")) || 1

    if (value < minValue) {
      input.value = minValue
    } else if (value > maxValue) {
      input.value = maxValue
    } else {
      input.value = Math.round((value - minValue) / step) * step + minValue
    }
  }
}
