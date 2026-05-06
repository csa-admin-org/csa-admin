import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["toggle", "input"]
  }

  connect() {
    if (this.hasToggleTarget) {
      this.updateToggle()
    }
  }

  updateToggle() {
    if (!this.hasToggleTarget) return

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

  toggleAll() {
    this.inputTargets.forEach((i) => {
      if (!i.disabled) {
        i.checked = this.toggleTarget.checked
      }
    })
    this.updateToggle()
    // Notify parent check-boxes-toggle-all controller
    const parent = this.element.closest(
      '[data-controller~="check-boxes-toggle-all"]'
    )
    if (parent) {
      const controller = this.application.getControllerForElementAndIdentifier(
        parent,
        "check-boxes-toggle-all"
      )
      if (controller) controller.updateToggle()
    }
  }
}
