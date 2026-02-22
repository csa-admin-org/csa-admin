import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["firstCweek", "lastCweek", "excludeCheckbox"]

  connect() {
    this.updateCheckboxState()
  }

  updateCheckboxState() {
    const firstHasValue = this.firstCweekTarget.value !== ""
    const lastHasValue = this.lastCweekTarget.value !== ""
    const bothHaveValues = firstHasValue && lastHasValue

    this.excludeCheckboxTarget.disabled = !bothHaveValues

    if (!bothHaveValues) {
      this.excludeCheckboxTarget.checked = false
    }
  }
}
