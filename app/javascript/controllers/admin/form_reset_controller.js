import { Controller } from "@hotwired/stimulus"
import { removeValues, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  reset(event) {
    const option = event?.currentTarget?.selectedOptions?.[0]
    if (option && "price" in option.dataset) {
      const price = option.dataset.price
      this.inputTargets.forEach((input) => {
        if (input.dataset.formResetPlaceholder === "price") {
          input.placeholder = price
        }
      })
    }

    removeValues(this.inputTargets)
    addClass(this.inputTargets, "animate-highlight")
    setTimeout(() => {
      removeClass(this.inputTargets, "animate-highlight")
    }, 1000)
  }
}
