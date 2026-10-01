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
  }

  connect() {
    this.dragging = false
    this.parkRange(parseFloat(this.inputTarget.value) || 0)
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

  syncFromInput() {
    let value = parseFloat(this.inputTarget.value) || 0
    let min = parseFloat(this.inputTarget.min)

    if (Number.isFinite(min) && value < min) {
      value = min
    }

    this.inputTarget.value = this.formatPrice(value)
    this.parkRange(value)
    this.updatePercent()
    this.refresh()
  }

  setDefaultPrice(event) {
    event.preventDefault()
    this.writePrice(this.defaultPriceValue)
    this.refresh()
  }

  writePrice(value) {
    this.inputTarget.value = this.formatPrice(value)
    this.parkRange(value)
    this.updatePercent()
    this.updateResetButtonDisabled()
  }

  parkRange(value) {
    let min = parseFloat(this.rangeTarget.min)
    let max = parseFloat(this.rangeTarget.max)
    let parked = value

    if (Number.isFinite(min) && parked < min) parked = min
    if (Number.isFinite(max) && parked > max) parked = max

    this.rangeTarget.value = this.formatPrice(parked)
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
    let value = parseFloat(this.inputTarget.value)
    this.resetTarget.disabled = this.samePrice(value, this.defaultPriceValue)
  }
}
