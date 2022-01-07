import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["item", "amount", "amountWrapper"]
  }

  connect() {
    this.updateAmount()
  }

  updateAmount() {
    if (this.itemTargets.length == 0) return

    let amount = 0.0
    for (const item of this.itemTargets) {
      amount = amount + item.value * item.dataset.price
    }
    this.amountWrapperTarget.style.display = "flex"
    this.amountTarget.textContent = this.amountTarget.textContent.replace(
      /\d+\.\d+/,
      Number(amount).toFixed(2)
    )
  }
}
