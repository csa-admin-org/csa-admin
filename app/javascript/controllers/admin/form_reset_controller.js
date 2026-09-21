import { Controller } from "@hotwired/stimulus"
import { removeValues, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["input"]
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

    removeValues(this.inputTargets)
    addClass(this.inputTargets, "animate-highlight")
    setTimeout(() => {
      removeClass(this.inputTargets, "animate-highlight")
    }, 1000)
  }
}
