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
    const data = this.latestBasketContentData()?.[this.unitSelectTarget.value]
    this.applyDefaults(data)
  }

  applyDefaults(data = null) {
    if (this.hasTotalQuantityInputTarget) {
      this.totalQuantityInputTarget.value = data?.quantity ?? ""
    }

    if (this.hasUnitPriceInputTarget) {
      this.unitPriceInputTarget.value = data?.unit_price ?? ""
    }

    this.applyBasketQuantities(data?.basket_size_ids_quantities)
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

  latestBasketContentData() {
    const rawData = this.productDataset("latestBasketContent")
    return rawData ? JSON.parse(rawData) : null
  }

  productDataset(key) {
    return this.productSelectTarget.selectedOptions[0]?.dataset[key]
  }
}
