import { Controller } from "@hotwired/stimulus"
import { checked, prop, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static targets = ["input"]

  excludeChoice(event) {
    for (const input of this.inputTargets) {
      const label = `label[for='${input.id}']`
      if (event.target.value === input.value) {
        addClass(label, "disabled")
        checked(input, false)
        prop(input, "disabled", true)
      } else {
        removeClass(label, "disabled")
        prop(input, "disabled", false)
      }
    }
  }
}
