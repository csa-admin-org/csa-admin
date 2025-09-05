import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

export default class extends Controller {
  static targets = ["range", "input", "reset"]
  static values = {
    defaultPrice: Number
  }

  initialize() {
    this.syncFromRange = debounce(100, this.syncFromRange)
    this.syncFromInput = debounce(600, this.syncFromInput)
  }

  syncFromRange() {
    let value = parseFloat(this.rangeTarget.value)

    this.inputTarget.value = value.toFixed(2)
    this.refresh()
  }

  syncFromInput() {
    let value = parseFloat(this.inputTarget.value) || 0
    let min = parseFloat(this.inputTarget.min)
    let max = parseFloat(this.inputTarget.max)

    if (min > value) {
      value = min
    }
    if (max < value) {
      value = max
    }
    this.inputTarget.value = value.toFixed(2)
    this.rangeTarget.value = this.inputTarget.value
    this.refresh()
  }

  setDefaultPrice(event) {
    let defaultPrice = parseFloat(this.defaultPriceValue)
    this.rangeTarget.value = defaultPrice.toFixed(2)
    this.inputTarget.value = defaultPrice.toFixed(2)
    this.refresh()
  }

  refresh() {
    const url = new URL(window.location)
    url.searchParams.set("price", this.inputTarget.value)
    Turbo.visit(url, { frame: "membership-pricing" })
    this.updateResetButtonDisabled()
  }

  updateResetButtonDisabled() {
    this.resetTarget.disabled =
      parseFloat(this.rangeTarget.value) === this.defaultPriceValue
  }
}
