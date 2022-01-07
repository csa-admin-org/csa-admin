import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  enforceMinValue({ params: { minValue } }) {
    if (!this.hasInputTarget) return

    if (this.inputTarget.getAttribute("min") != minValue) {
      this.inputTarget.setAttribute("min", minValue)
      this.inputTarget.value = minValue
    }
  }
}
