import { Controller } from "@hotwired/stimulus"

// Enables/disables the exclude_cweek_range checkbox based on whether
// both first_cweek and last_cweek selects have values.
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
