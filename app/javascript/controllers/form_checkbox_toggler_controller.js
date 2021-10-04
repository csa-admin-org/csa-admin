import { Controller } from "@hotwired/stimulus"
import { prop } from "components/utils"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.toggleInput()
  }

  toggleInput() {
    for (const input of this.inputTargets) {
      prop(input, "disabled", input.getAttribute("disabled") != "disabled")
    }
  }
}
