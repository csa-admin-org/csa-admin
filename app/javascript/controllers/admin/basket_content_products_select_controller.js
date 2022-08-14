import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "productSelect",
    "unitSelect",
    "quantityInput",
    "unitPriceInput",
  ]

  productChange() {
    const latestUnit = this._productDataset('latestBasketContentUnit')
    if(latestUnit) {
      this.unitSelectTarget.value = latestUnit
      this.unitChange()
    } else {
      this.unitSelectTarget.value = null
      this.quantityInputTarget.value = null
      this.unitPriceInputTarget.value = null
    }
  }

  unitChange() {
    const data = JSON.parse(this._productDataset('latestBasketContent'))
    const unit = this.unitSelectTarget.value
    if (data && data[unit]) {
      this.quantityInputTarget.value = data[unit]['quantity']
      this.unitPriceInputTarget.value = data[unit]['unit_price']
    } else {
      this.quantityInputTarget.value = null
      this.unitPriceInputTarget.value = null
    }
  }

  _productDataset(keyname) {
    return this.productSelectTarget.selectedOptions[0].dataset[keyname]
  }
}
