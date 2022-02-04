import { Controller } from "@hotwired/stimulus"
import { checked, prop, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  connect() {
    for (const input of this.inputTargets) {
      if (input.disabled) {
        const label = `label[for='${input.id}']`
        addClass(label, "disabled")
      }
    }
  }

  limitChoices(event) {
    const values = event.params.values.toString().split(',')
    if(this.hasInputTarget) {
      for (const input of this.inputTargets) {
        const label = `label[for='${input.id}']`
        if (values.includes(input.value)) {
          removeClass(label, "disabled")
          prop(input, "disabled", false)
        } else {
          addClass(label, "disabled")
          checked(input, false)
          prop(input, "disabled", true)
        }
      }
      checked(Array.from(this.inputTargets).find((i) => !i.disabled), true)
    }
  }
}
