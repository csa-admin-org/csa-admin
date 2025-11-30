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
    if (
      this.inputTargets.length >= 2 &&
      !this.toggleTarget.closest("form.filter_form")
    ) {
      show(this.toggleTarget)
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
  }
}
