import { Controller } from "@hotwired/stimulus"
import { removeValues, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static targets = ["input", "quantity", "quantityLabel", "priceSuffix"]
  static values = { quantityLabels: Object, priceSuffixes: Object }

  connect() {
    this.applyQuantityStep()
  }

  reset(event) {
    const option = event?.currentTarget?.selectedOptions?.[0]
    if (option) {
      this.inputTargets.forEach((input) => {
        const key = input.dataset.formResetPlaceholder
        if (key && key in option.dataset) {
          input.placeholder = option.dataset[key]
        }
      })
    }
    this.applyQuantityStep(event?.currentTarget)

    removeValues(this.inputTargets)
    addClass(this.inputTargets, "animate-highlight")
    setTimeout(() => {
      removeClass(this.inputTargets, "animate-highlight")
    }, 1000)
  }

  applyQuantityStep(select) {
    if (!this.hasQuantityTarget) return

    select ||= this.element.querySelector("select")
    const unit = select?.selectedOptions?.[0]?.dataset?.unit
    const kilograms = unit === "kg"
    this.quantityTarget.step = kilograms ? "0.01" : "1"
    this.quantityTarget.min = kilograms ? "0.01" : "1"
    const key = kilograms ? "kg" : "pc"
    if (this.hasQuantityLabelTarget) {
      this.setLabel(this.quantityLabelTarget, this.quantityLabelsValue[key])
    }
    if (this.hasPriceSuffixTarget) {
      this.priceSuffixTarget.textContent = this.priceSuffixesValue[key] || ""
    }
  }

  setLabel(label, text) {
    if (!label || !text) return

    const textNode = [...label.childNodes].find(
      (node) => node.nodeType === Node.TEXT_NODE && node.textContent.trim()
    )
    if (textNode) textNode.textContent = text
    else label.prepend(text)
  }
}
