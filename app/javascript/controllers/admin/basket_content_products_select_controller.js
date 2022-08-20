import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [
      "productSelect",
      "unitSelect",
      "quantityInput",
      "unitPriceInput",
    ]
  }

  productChange() {
    const latestUnit = this._productDataset('latestBasketContentUnit')
    if(latestUnit) {
      this.unitSelectTarget.value = latestUnit
      this.unitChange()
    } else {
      this.unitSelectTarget.value = ''
      this.quantityInputTarget.value = ''
      this.unitPriceInputTarget.value = ''
    }
  }

  unitChange() {
    const rawData = this._productDataset('latestBasketContent')
    const data = rawData && JSON.parse(rawData)
    const unit = this.unitSelectTarget.value
    if (data && data[unit]) {
      this.quantityInputTarget.value = data[unit]['quantity']
      this.unitPriceInputTarget.value = data[unit]['unit_price']
    } else {
      this.quantityInputTarget.value = ''
      this.unitPriceInputTarget.value = ''
    }
  }

  _productDataset(keyname) {
    return this.productSelectTarget.selectedOptions[0].dataset[keyname]
  }
}
