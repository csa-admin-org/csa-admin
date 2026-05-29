import { Controller } from "@hotwired/stimulus"
import { prop, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["label", "input"]
  }

  toggleInputs(event) {
    const target = event.target
    let shouldEnable = false

    if (target.type === "checkbox") {
      shouldEnable = target.checked
    } else if (target.tagName === "SELECT") {
      shouldEnable = target.value !== ""
    }

    if (shouldEnable) {
      this.enableInputs()
    } else {
      this.disableInputs()
    }
  }

  enableInputs() {
    removeClass(this.labelTargets, "disabled")
    prop(this.inputTargets, "disabled", false)
    for (const input of this.inputTargets) {
      if (input.value == "") input.value = input.dataset.defaultValue
    }
    this.dispatch("state-changed")
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
    this.dispatch("state-changed")
  }
}
