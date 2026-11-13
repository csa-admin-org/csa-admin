import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "text", "stock", "stockLabel", "weight", "complement"]
  static values = { suffixes: Object, stockLabels: Object }

  connect() {
    this.update()
  }

  update() {
    const unit = this.selectTarget.value
    this.textTarget.textContent = this.suffixesValue[unit] || ""
    const kilograms = unit === "kg"
    if (this.hasStockTarget) {
      this.stockTarget.step = kilograms ? "0.01" : "1"
    }
    if (this.hasStockLabelTarget) {
      this.stockLabelTarget.textContent = this.stockLabelsValue[unit] || ""
    }
    if (this.hasWeightTarget) this.toggle(this.weightTarget, kilograms)
    if (this.hasComplementTarget)
      this.toggle(this.complementTarget, kilograms && !this.complementValue())
  }

  toggle(element, hide) {
    element.hidden = hide
    element.classList.toggle("hidden", hide)
  }

  complementValue() {
    return this.complementTarget.querySelector("select")?.value
  }
}
