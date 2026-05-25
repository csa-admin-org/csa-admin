import { Controller } from "@hotwired/stimulus"
import { show } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["toggle", "input"]
  }

  connect() {
    this.updateToggle()
  }

  updateToggle() {
    if (this.inputTargets.length >= 2 && !this.toggleTarget.closest("form.filter_form")) {
      show(this.toggleTarget)
      const allDisabled = this.inputTargets.length > 0 && this.inputTargets.every((i) => i.disabled)
      this.toggleTarget.disabled = allDisabled

      const checkedCount = this.inputTargets.filter((i) => i.checked).length
      const totalCount = this.inputTargets.length

      if (checkedCount === 0) {
        this.toggleTarget.checked = false
        this.toggleTarget.indeterminate = false
      } else if (checkedCount === totalCount) {
        this.toggleTarget.checked = true
        this.toggleTarget.indeterminate = false
      } else {
        this.toggleTarget.checked = false
        this.toggleTarget.indeterminate = true
      }
    }
  }

  toggleAll() {
    this.inputTargets.forEach((i) => {
      if (!i.disabled) {
        i.checked = this.toggleTarget.checked
      }
    })
    this.updateToggle()
    // Notify nested group toggle controllers
    this.element.querySelectorAll('[data-controller~="check-boxes-group-toggle"]').forEach((el) => {
      const controller = this.application.getControllerForElementAndIdentifier(
        el,
        "check-boxes-group-toggle"
      )
      if (controller) controller.updateToggle()
    })
  }
}
