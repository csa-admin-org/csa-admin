import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

const SNAP_DISTANCE = 5

export default class extends Controller {
  static targets = ["range", "input", "reset", "percent"]
  static values = {
    defaultPrice: Number,
    snapPrices: Array
  }

  initialize() {
    this.queuePricingRefresh = debounce(100, this.refresh.bind(this))
    this.syncFromInput = debounce(600, this.syncFromInput.bind(this))
  }

  connect() {
    this.dragging = false
    this.updatePercent()
    this.endDrag = this.endDrag.bind(this)
    document.addEventListener("pointerup", this.endDrag)
    document.addEventListener("pointercancel", this.endDrag)
  }

  disconnect() {
    document.removeEventListener("pointerup", this.endDrag)
    document.removeEventListener("pointercancel", this.endDrag)
  }

  startDrag() {
    this.dragging = true
  }

  endDrag() {
    this.dragging = false
  }

  syncFromRange() {
    let raw = parseFloat(this.rangeTarget.value)
    let value = this.dragging ? this.magnet(raw) : raw

    if (Math.abs(value - raw) >= 0.001) {
      this.rangeTarget.value = this.formatPrice(value)
    }
    this.inputTarget.value = this.formatPrice(value)
    this.updatePercent()
    this.updateResetButtonDisabled()
    this.queuePricingRefresh()
  }

  allowCentPrice(event) {
    let validity = this.inputTarget.validity
    if (!validity.stepMismatch) return
    if (validity.rangeUnderflow || validity.rangeOverflow || validity.valueMissing) return

    event.preventDefault()
    this.inputTarget.step = "any"
    this.inputTarget.form.requestSubmit()
    this.inputTarget.step = "0.5"
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
    this.inputTarget.value = this.formatPrice(value)
    this.rangeTarget.value = this.inputTarget.value
    this.updatePercent()
    this.refresh()
  }

  setDefaultPrice(event) {
    event.preventDefault()
    this.writePrice(this.defaultPriceValue)
    this.refresh()
  }

  writePrice(value) {
    let formatted = this.formatPrice(value)
    this.rangeTarget.value = formatted
    this.inputTarget.value = formatted
    this.updatePercent()
    this.updateResetButtonDisabled()
  }

  magnet(value) {
    if (!Number.isFinite(value)) return value

    let min = parseFloat(this.rangeTarget.min)
    let max = parseFloat(this.rangeTarget.max)
    let span = max - min
    if (!(span > 0)) return value

    let width = this.rangeTarget.getBoundingClientRect().width
    if (!(width > 0)) return value

    let target = this.nearestSnap(value, min, max, span * (SNAP_DISTANCE / width))
    return target == null ? value : target
  }

  nearestSnap(value, min, max, threshold) {
    let best = null
    let bestDistance = threshold

    this.snapPricesValue.forEach((price) => {
      let candidate = parseFloat(price)
      if (!Number.isFinite(candidate) || candidate < min || candidate > max) return

      let distance = Math.abs(value - candidate)
      if (distance > bestDistance) return
      if (distance === bestDistance && !this.samePrice(candidate, this.defaultPriceValue)) return

      best = this.samePrice(candidate, this.defaultPriceValue) ? this.defaultPriceValue : candidate
      bestDistance = distance
    })

    return best
  }

  samePrice(left, right) {
    return Math.abs(left - right) <= 0.005
  }

  formatPrice(value) {
    return (parseFloat(value) || 0).toFixed(2)
  }

  refresh() {
    const url = new URL(window.location)
    url.searchParams.set("price", this.inputTarget.value)
    Turbo.visit(url, { frame: "membership-pricing" })
    this.updateResetButtonDisabled()
  }

  updatePercent() {
    if (!this.hasPercentTarget) return

    let baseline = this.defaultPriceValue
    let value = parseFloat(this.inputTarget.value)
    if (!baseline || !Number.isFinite(value)) {
      this.percentTarget.textContent = ""
      return
    }

    let difference = Math.round(((value - baseline) / baseline) * 100)
    if (!difference) {
      this.percentTarget.textContent = ""
      return
    }

    let sign = difference > 0 ? "+" : ""
    this.percentTarget.textContent = `${sign}${difference}%`
  }

  updateResetButtonDisabled() {
    let value = parseFloat(this.rangeTarget.value)
    this.resetTarget.disabled = Math.abs(value - this.defaultPriceValue) <= 0.005
  }
}
