import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  enforce(event) {
    let input = event.target
    let value = parseInt(input.value)

    let minValue = input.getAttribute("min")
    if (minValue && value < minValue) {
      input.value = minValue
    }

    let maxValue = input.getAttribute("max")
    if (maxValue && value > maxValue) {
      input.value = maxValue
    }
  }
}
