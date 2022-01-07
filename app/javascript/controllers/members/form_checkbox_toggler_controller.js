import { Controller } from "@hotwired/stimulus"
import { prop } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["checkbox", "input"]
  }

  connect() {
    if (!this.checkboxTarget.checked) {
      this.toggleInput()
    }
  }

  toggleInput() {
    for (const input of this.inputTargets) {
      prop(input, "disabled", input.getAttribute("disabled") != "disabled")
    }
  }
}
