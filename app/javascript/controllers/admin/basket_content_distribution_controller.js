import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

const PRESET_TOLERANCE = 2.0

export default class extends Controller {
  static get targets() {
    return ["totalQuantity", "range", "quantityInput", "percentageLabel", "preset", "frame"]
  }

  static get values() {
    return {
      url: String,
      id: { type: String, default: "" },
      pcSuffix: { type: String, default: "pc" },
      kgPriceSuffix: { type: String, default: "" },
      pcPriceSuffix: { type: String, default: "" }
    }
  }

  initialize() {
    this.debouncedFetchPrices = debounce(300, () => this.fetchPrices())
    this.debouncedTotalQuantityChanged = debounce(700, () => {
      this.applyTotalQuantityChange({ round: false })
    })
    this.debouncedQuantityChanged = debounce(700, () => {
      this.applyQuantityChange()
    })
    this._onFrameLoad = () => this.distribute()
  }

  connect() {
    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("turbo:frame-load", this._onFrameLoad)
    }

    this.distributionSource = "quantity"
    this.updateAll()
    this.refresh()
  }

  disconnect() {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("turbo:frame-load", this._onFrameLoad)
    }

    this.clearPrices()
  }

  // --- Event handlers ---

  formChanged(event) {
    if (this.isDistributionInput(event.target)) return

    this.refresh()
  }

  productDefaultsChanged() {
    this.markDistributionSource("quantity")
    this.recalculateFromQuantities()
    this.refresh()
  }

  totalQuantityChanging() {
    this.markDistributionSource("total")
    this.debouncedTotalQuantityChanged()
  }

  totalQuantityChanged() {
    this.markDistributionSource("total")
    this.cancelPending(this.debouncedTotalQuantityChanged)
    this.applyTotalQuantityChange({ round: true })
  }

  applyTotalQuantityChange({ round, refresh = true }) {
    if (round) this.roundTotalQuantityInput()

    if (this.totalQuantity() > 0) {
      this.computeQuantitiesFromPercentages()
      this.computePercentagesFromQuantities()
    } else {
      this.clearQuantities()
    }

    this.updateAll()
    if (refresh) this.refresh()
  }

  percentageChanged(event) {
    this.markDistributionSource("total")
    this.rebalanceRanges(event.currentTarget)
    this.computeQuantitiesFromPercentages()
    this.updateAll()
    this.refresh()
  }

  quantityChanging() {
    this.markDistributionSource("quantity")
    this.debouncedQuantityChanged()
  }

  quantityChanged() {
    this.markDistributionSource("quantity")
    this.cancelPending(this.debouncedQuantityChanged)
    this.applyQuantityChange()
  }

  applyQuantityChange() {
    this.recalculateFromQuantities()
    this.refresh()
  }

  applyPreset(event) {
    event.preventDefault()
    this.markDistributionSource("total")

    Object.entries(JSON.parse(event.currentTarget.dataset.preset)).forEach(
      ([basketSizeId, value]) => {
        const range = this.rangeByBasketSizeId(basketSizeId)
        if (range) range.value = this.roundPercentage(value)
      }
    )

    this.computeQuantitiesFromPercentages()
    this.computeTotalFromQuantities()
    this.computePercentagesFromQuantities()
    this.updateAll()
    this.refresh()
  }

  // --- Quantity ↔ Percentage computation ---

  recalculateFromQuantities() {
    this.computeTotalFromQuantities()
    this.computePercentagesFromQuantities()
    this.updateAll()
  }

  computeQuantitiesFromPercentages() {
    const total = this.totalQuantity()
    if (total <= 0) return

    const weightedSum = this.quantityInputTargets.reduce((sum, input) => {
      return sum + this.basketsCountFor(input) * this.percentageFor(input)
    }, 0)
    if (weightedSum <= 0) return

    this.quantityInputTargets.forEach((input) => {
      const count = this.basketsCountFor(input)
      const percentage = this.percentageFor(input)

      if (count === 0 || percentage === 0) {
        input.value = 0
      } else {
        const quantity = (total * percentage) / weightedSum
        if (this.currentUnit() === "kg") {
          const grams = Math.round(quantity * 1000)
          input.value = grams >= 100 ? Math.round(grams / 10) * 10 : grams
        } else {
          input.value = Math.round(quantity)
        }
      }
    })

    this.ensureMinimumTotal()
  }

  ensureMinimumTotal() {
    if (this.currentUnit() === "kg" || !this.hasTotalQuantityTarget) return

    const requiredTotal = this.quantityInputTargets.reduce((sum, input) => {
      const quantity = parseFloat(input.value) || 0
      return sum + quantity * this.basketsCountFor(input)
    }, 0)

    const rounded = this.roundTotalQuantity(requiredTotal)
    if (rounded > this.totalQuantity()) {
      this.totalQuantityTarget.value = rounded
    }
  }

  computeTotalFromQuantities() {
    if (!this.hasTotalQuantityTarget) return

    if (this.currentUnit() === "kg") {
      const totalGrams = this.quantityInputTargets.reduce((sum, input) => {
        return sum + this.quantityInGrams(input) * this.basketsCountFor(input)
      }, 0)
      this.totalQuantityTarget.value = this.roundTotalGrams(totalGrams)
      return
    }

    const total = this.quantityInputTargets.reduce((sum, input) => {
      const quantity = parseFloat(input.value) || 0
      return sum + quantity * this.basketsCountFor(input)
    }, 0)

    this.totalQuantityTarget.value = this.roundTotalQuantity(total)
  }

  computePercentagesFromQuantities() {
    const quantities = this.quantityInputTargets.map((input) => {
      return parseFloat(input.value) || 0
    })
    const total = quantities.reduce((sum, quantity) => sum + quantity, 0)
    if (total <= 0) return

    const percentages = quantities.map((quantity) => {
      return this.roundPercentage((quantity / total) * 100)
    })
    percentages[percentages.length - 1] = this.clampPercentage(
      percentages[percentages.length - 1] + this.percentageDiff(percentages)
    )

    this.quantityInputTargets.forEach((input, index) => {
      const range = this.rangeFor(input)
      if (range) range.value = percentages[index]
    })
  }

  clearQuantities() {
    this.quantityInputTargets.forEach((input) => (input.value = ""))
  }

  totalQuantity() {
    if (!this.hasTotalQuantityTarget) return 0

    return parseFloat(this.totalQuantityTarget.value) || 0
  }

  roundTotalQuantityInput() {
    if (!this.hasTotalQuantityTarget) return

    this.totalQuantityTarget.value = this.roundTotalQuantity(this.totalQuantity())
  }

  roundTotalQuantity(total) {
    if (total <= 0) return ""

    if (this.currentUnit() === "pc") {
      return total < 10 ? Math.ceil(total) : Math.ceil(total / 10) * 10
    }

    return this.roundTotalGrams(Math.round(total * 1000))
  }

  roundTotalGrams(totalGrams) {
    if (totalGrams <= 0) return ""

    return Math.ceil(totalGrams / 1000)
  }

  quantityInGrams(input) {
    return Math.round(parseFloat(input.value) || 0)
  }

  // --- Percentage helpers ---

  rebalanceRanges(target) {
    target.value = this.clampPercentage(target.value)

    const others = this.rangeTargets.filter((range) => range !== target)
    if (others.length === 0) return

    const remaining = this.roundPercentage(100 - parseFloat(target.value))
    if (remaining <= 0) {
      others.forEach((range) => (range.value = 0))
      return
    }

    const otherTotal = others.reduce((sum, range) => {
      return sum + (parseFloat(range.value) || 0)
    }, 0)
    const percentages = others.map((range) => {
      const value = parseFloat(range.value) || 0
      return otherTotal > 0 ? (value / otherTotal) * remaining : remaining / others.length
    })
    const roundedPercentages = percentages.map((value) => {
      return this.clampPercentage(value)
    })
    roundedPercentages[roundedPercentages.length - 1] = this.clampPercentage(
      roundedPercentages[roundedPercentages.length - 1] +
        this.roundPercentage(remaining - roundedPercentages.reduce((sum, value) => sum + value, 0))
    )

    others.forEach((range, index) => (range.value = roundedPercentages[index]))
  }

  percentageDiff(percentages) {
    return this.roundPercentage(100 - percentages.reduce((sum, percentage) => sum + percentage, 0))
  }

  percentageFor(input) {
    return parseFloat(this.rangeFor(input)?.value) || 0
  }

  rangeFor(input) {
    return input
      .closest(".bc-size-row")
      ?.querySelector('[data-basket-content-distribution-target~="range"]')
  }

  rangeByBasketSizeId(id) {
    return document.getElementById(`basket_size_ids_percentages_${id}_range`)
  }

  basketsCountFor(input) {
    return parseFloat(input.closest(".bc-size-row")?.dataset.basketsCount) || 0
  }

  roundPercentage(value) {
    return Math.round((parseFloat(value) || 0) * 100) / 100
  }

  clampPercentage(value) {
    return Math.min(100, Math.max(0, this.roundPercentage(value)))
  }

  // --- Price preview ---

  refresh() {
    this.updateUnitSuffixes()
    this.debouncedFetchPrices()
  }

  fetchPrices() {
    if (!this.hasFrameTarget || !this.hasUrlValue) return

    const formData = new FormData(this.form)
    const deliveryId = formData.get("basket_content[delivery_id]")
    const unitPrice = formData.get("basket_content[unit_price]")
    const unit = this.currentUnit()

    if (!deliveryId) {
      this.clearPrices()
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("delivery_id", deliveryId)
    if (formData.get("basket_content[product_id]")) {
      url.searchParams.set("product_id", formData.get("basket_content[product_id]"))
    }
    if (unitPrice !== "") url.searchParams.set("unit_price", unitPrice)
    if (unit) url.searchParams.set("unit", unit)

    if (this.idValue) url.searchParams.set("id", this.idValue)

    this.appendQuantityParams(url, formData)
    this.appendDepotParams(url, formData)
    this.frameTarget.src = url.toString()
  }

  appendQuantityParams(url, formData) {
    for (const [key, value] of formData.entries()) {
      const match = key.match(/^basket_content\[basket_size_ids_quantities\]\[(\d+)\]$/)
      if (match) url.searchParams.set(`basket_size_ids_quantities[${match[1]}]`, value)
    }
  }

  appendDepotParams(url, formData) {
    const depotIds = formData.getAll("basket_content[depot_ids][]").filter((value) => value !== "")

    if (depotIds.length === 0) {
      url.searchParams.set("depot_ids_empty", "1")
    } else {
      depotIds.forEach((id) => url.searchParams.append("depot_ids[]", id))
    }
  }

  distribute() {
    this.clearPrices()
    this.updateUnitFromFrame()
    const countsChanged = this.updateBasketsCountsFromFrame()
    if (this.distributionInputFocused()) {
      this.updateAll()
    } else if (countsChanged) {
      this.synchronizeDistributionAfterRefresh()
    }
    this.updateTotalProductValueFromFrame()
    this.updatePricesFromFrame()
  }

  updateUnitFromFrame() {
    const unit = this.frameTarget.querySelector("[data-unit]")?.dataset.unit
    if (unit) this.updateUnitSuffixes(unit)
  }

  updateBasketsCountsFromFrame() {
    let changed = false
    this.frameTarget.querySelectorAll("[data-baskets-count-for]").forEach((source) => {
      this.rowsFor(source.dataset.basketsCountFor).forEach((row) => {
        if (row.dataset.basketsCount !== source.dataset.basketsCount) {
          row.dataset.basketsCount = source.dataset.basketsCount
          changed = true
        }
      })
    })
    return changed
  }

  updateTotalProductValueFromFrame() {
    const source = this.frameTarget.querySelector("[data-total-product-value]")
    const target = this.element.querySelector(".bc-total-form-price")
    if (target && source) target.innerHTML = source.innerHTML
  }

  updatePricesFromFrame() {
    this.frameTarget.querySelectorAll("[data-basket-size-id]").forEach((source) => {
      this.rowsFor(source.dataset.basketSizeId).forEach((row) => {
        const price = row.querySelector(".bc-form-price")
        if (price) price.innerHTML = source.innerHTML
      })
    })
  }

  rowsFor(basketSizeId) {
    return this.element.querySelectorAll(`.bc-size-row[data-basket-size-id="${basketSizeId}"]`)
  }

  clearPrices() {
    this.element.querySelectorAll(".bc-form-price, .bc-total-form-price").forEach((price) => {
      price.innerHTML = ""
    })
  }

  synchronizeDistributionAfterRefresh() {
    if (this.distributionSource === "total") {
      this.applyTotalQuantityChange({ round: false, refresh: false })
    } else {
      this.recalculateFromQuantities()
    }
  }

  // --- UI state ---

  updateAll() {
    this.updateRangeAvailability()
    this.updatePercentageLabels()
    this.updatePresetStates()
    this.updateUnitSuffixes()
  }

  updatePercentageLabels() {
    if (!this.hasPercentageLabelTarget) return

    const rounded = this.rangeTargets.map((range) => Math.round(parseFloat(range.value) || 0))
    const sum = rounded.reduce((s, v) => s + v, 0)
    const approximate = sum !== 100 && sum !== 0

    this.percentageLabelTargets.forEach((label, index) => {
      const value = rounded[index] ?? 0
      label.textContent = approximate ? `~${value}%` : `${value}%`
    })
  }

  updateRangeAvailability() {
    if (!this.hasTotalQuantityTarget) return

    const disabled = this.totalQuantity() <= 0
    this.rangeTargets.forEach((range) => (range.disabled = disabled))
  }

  updatePresetStates() {
    this.presetTargets.forEach((button) => {
      const preset = Object.entries(JSON.parse(button.dataset.preset))
      button.disabled = preset.every(([basketSizeId, value]) => {
        const range = this.rangeByBasketSizeId(basketSizeId)
        return range && Math.abs(parseFloat(range.value) - parseFloat(value)) < PRESET_TOLERANCE
      })
    })
  }

  updateUnitSuffixes(unit = this.currentUnit()) {
    if (!unit) return

    const quantitySuffix = unit === "pc" ? this.pcSuffixValue : "g"
    this.element.querySelectorAll(".bc-unit-suffix").forEach((suffix) => {
      suffix.textContent = quantitySuffix
    })

    const totalSuffix = unit === "pc" ? this.pcSuffixValue : "kg"
    this.element.querySelectorAll(".bc-total-unit-suffix").forEach((suffix) => {
      suffix.textContent = totalSuffix
    })

    const priceSuffix = unit === "pc" ? this.pcPriceSuffixValue : this.kgPriceSuffixValue
    this.element.querySelectorAll(".bc-price-unit-suffix").forEach((suffix) => {
      suffix.textContent = priceSuffix
    })
  }

  // --- Helpers ---

  cancelPending(debouncedCallback) {
    debouncedCallback.cancel?.({ upcomingOnly: true })
  }

  markDistributionSource(source) {
    this.distributionSource = source
  }

  get form() {
    return this.element.closest("form") || this.element
  }

  currentUnit() {
    const select = this.element.querySelector(
      '[data-basket-content-products-select-target="productSelect"]'
    )
    return select?.selectedOptions[0]?.dataset.unit || "kg"
  }

  distributionInputFocused() {
    return this.isDistributionInput(document.activeElement)
  }

  isDistributionInput(target) {
    return target?.matches?.(
      [
        '[data-basket-content-distribution-target~="totalQuantity"]',
        '[data-basket-content-distribution-target~="range"]',
        '[data-basket-content-distribution-target~="quantityInput"]'
      ].join(",")
    )
  }
}
