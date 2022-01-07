import { Controller } from "@hotwired/stimulus"
import { prop, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["label", "input"]
  }

  enableInputs() {
    removeClass(this.labelTargets, "disabled")
    prop(this.inputTargets, "disabled", false)
    for (const input of this.inputTargets) {
      if (input.value == "") input.value = input.dataset.defaultValue
    }
  }

  disableInputs() {
    addClass(this.labelTargets, "disabled")
    prop(this.inputTargets, "disabled", true)
    for (const input of this.inputTargets) {
      switch (input.type) {
        case "number":
          input.value = null
          break
        case "radio":
        case "checkbox":
          input.checked = input.value === input.dataset.disabledValue
          break
      }
    }
  }
}
