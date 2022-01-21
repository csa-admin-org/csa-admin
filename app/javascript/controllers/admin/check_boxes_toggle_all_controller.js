import { Controller } from "@hotwired/stimulus"
import { show } from "components/utils"

export default class extends Controller {
  static targets = ["toggle", "input"]

  connect() {
    this.updateToggle()
  }

  updateToggle() {
    if (
      this.inputTargets.length > 2 &&
      !this.toggleTarget.closest("form.filter_form") &&
      !this.toggleTarget.closest("li.no-check-boxes-toggle-all")
    ) {
      show(this.toggleTarget)
      this.toggleTarget.checked = this.inputTargets.every((i) => i.checked)
    }
  }

  toggleAll() {
    this.inputTargets.forEach((i) => {
      if (!i.disabled) {
        i.checked = this.toggleTarget.checked
      }
    })
  }
}
