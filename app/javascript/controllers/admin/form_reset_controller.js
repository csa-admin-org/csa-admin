import { Controller } from "@hotwired/stimulus"
import { removeValues, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  reset() {
    removeValues(this.inputTargets)
    addClass(this.inputTargets, "animate-highlight")
    setTimeout(() => {
      removeClass(this.inputTargets, "animate-highlight")
    }, 1000)
  }
}
