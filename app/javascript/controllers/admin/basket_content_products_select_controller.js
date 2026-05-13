import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [
      "productSelect",
      "unitSelect",
      "totalQuantityInput",
      "unitPriceInput"
    ]
  }

  productChange() {
    const latestUnit = this.productDataset("latestBasketContentUnit")
    this.unitSelectTarget.value = latestUnit || ""
    this.unitChange()
  }

  unitChange() {
    const selectedUnit = this.unitSelectTarget.value
    const latestUnit = this.productDataset("latestBasketContentUnit")
    const matchesLatest = selectedUnit && selectedUnit === latestUnit
    this.applyDefaults(matchesLatest)
  }

  applyDefaults(matchesLatest = false) {
    if (this.hasTotalQuantityInputTarget) {
      this.totalQuantityInputTarget.value = ""
    }

    if (this.hasUnitPriceInputTarget) {
      this.unitPriceInputTarget.value = matchesLatest
        ? (this.productDataset("latestBasketContentUnitPrice") ?? "")
        : ""
    }

    this.applyBasketQuantities(
      matchesLatest ? this.latestBasketContentQuantities() : null
    )
    this.element.dispatchEvent(
      new CustomEvent("basket-content-products-updated", { bubbles: true })
    )
  }

  applyBasketQuantities(quantities) {
    this.basketQuantityInputs().forEach((input) => {
      const basketSizeId = input.id.match(/_(\d+)$/)?.[1]
      input.value =
        quantities && basketSizeId ? (quantities[basketSizeId] ?? 0) : ""
    })
  }

  basketQuantityInputs() {
    return this.element.querySelectorAll(
      'input[name^="basket_content[basket_size_ids_quantities]"]'
    )
  }

  latestBasketContentQuantities() {
    const rawData = this.productDataset("latestBasketContentQuantities")
    return rawData ? JSON.parse(rawData) : null
  }

  productDataset(key) {
    return this.productSelectTarget.selectedOptions[0]?.dataset[key]
  }
}
