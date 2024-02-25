import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  updateInput(event) {
    if (!this.hasInputTarget) return

    this._updateInputValue()
    this._updateInputMinMax()
  }

  _updateInputValue() {
    const inputsArray = Array.from(document.querySelectorAll('input[data-activity]'))
    let count = 0
    inputsArray.forEach((input) => {
      if (input.type == "radio" && input.checked) {
        count += parseInt(input.dataset.activity)
      }
      if (input.type == "number") {
        count += input.value * parseInt(input.dataset.activity)
      }
    })
    this.inputTarget.value = count;
  }

  _updateInputMinMax() {
    let min = parseInt(this.inputTarget.dataset.min)
    let max = parseInt(this.inputTarget.dataset.max)

    if (this.inputTarget.dataset.min) {
      if (min <= this.inputTarget.value) {
        this.inputTarget.min = min
      } else {
        this.inputTarget.min = this.inputTarget.value
      }
    } else {
      this.inputTarget.min = this.inputTarget.value
    }
    if (this.inputTarget.dataset.max) {
      if (this.inputTarget.value <= max) {
        this.inputTarget.max = max
      } else {
        this.inputTarget.max = this.inputTarget.value
      }
    } else {
      this.inputTarget.max = this.inputTarget.value
    }
  }
}
