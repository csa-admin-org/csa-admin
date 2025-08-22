import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

export default class extends Controller {
  static targets = ["range", "input", "reset"]
  static values = {
    defaultPrice: Number
  }

  initialize() {
    this.syncFromRange = debounce(100, this.syncFromRange)
    this.syncFromInput = debounce(100, this.syncFromInput)
  }

  syncFromRange() {
    let value = parseFloat(this.rangeTarget.value).toFixed(2)

    this.inputTarget.value = value
    this.refresh()
  }

  syncFromInput() {
    if (this.inputTarget.value === "") {
      this.rangeTarget.value = 0
      return
    }

    let value = parseFloat(this.inputTarget.value).toFixed(2)
    let min = parseFloat(this.inputTarget.min).toFixed(2)
    let max = parseFloat(this.inputTarget.max).toFixed(2)

    if (min > value) {
      this.inputTarget.value = min
    }
    if (max < value) {
      this.inputTarget.value = max
    }
    this.inputTarget.value = value
    this.rangeTarget.value = value
    this.refresh()
  }

  setDefaultPrice(event) {
    let defaultPrice = parseFloat(this.defaultPriceValue).toFixed(2)
    this.rangeTarget.value = defaultPrice
    this.inputTarget.value = defaultPrice
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
