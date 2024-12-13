import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  setMinValue({ params: { minValue } }) {
    if (!this.hasInputTarget) return

    const inputMinValue = Number(this.inputTarget.getAttribute("min"))
    if (inputMinValue != minValue) {
      this.inputTarget.setAttribute("min", minValue)
      if (this.inputTarget.value < minValue) {
        this.inputTarget.value = minValue
      }
    }
  }
}
