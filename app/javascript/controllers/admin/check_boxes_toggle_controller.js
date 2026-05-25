import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["toggle", "input", "groupToggle"]
  }

  connect() {
    this.updateToggle()
  }

  updateToggle() {
    if (!this.hasToggleTarget) return

    // Global toggle state
    const allInputs = this.inputTargets
    const checked = allInputs.filter((i) => i.checked).length
    const total = allInputs.length

    if (checked === 0) {
      this.toggleTarget.checked = false
      this.toggleTarget.indeterminate = false
    } else if (checked === total) {
      this.toggleTarget.checked = true
      this.toggleTarget.indeterminate = false
    } else {
      this.toggleTarget.checked = false
      this.toggleTarget.indeterminate = true
    }

    const allDisabled = total > 0 && allInputs.every((i) => i.disabled)
    this.toggleTarget.disabled = allDisabled

    // Group toggles
    this.groupToggleTargets.forEach((groupToggle) => {
      const container = groupToggle.closest(".choices-group-container")
      const groupInputs = container
        ? container.querySelectorAll('input[data-check-boxes-toggle-target="input"]')
        : []

      const gChecked = Array.from(groupInputs).filter((i) => i.checked).length
      const gTotal = groupInputs.length

      if (gChecked === 0) {
        groupToggle.checked = false
        groupToggle.indeterminate = false
      } else if (gChecked === gTotal) {
        groupToggle.checked = true
        groupToggle.indeterminate = false
      } else {
        groupToggle.checked = false
        groupToggle.indeterminate = true
      }

      const gDisabled = gTotal > 0 && Array.from(groupInputs).every((i) => i.disabled)
      groupToggle.disabled = gDisabled
    })
  }

  toggleAll() {
    this.inputTargets.forEach((i) => {
      if (!i.disabled) i.checked = this.toggleTarget.checked
    })
    this.updateToggle()
  }

  toggleGroup(event) {
    const toggle = event.currentTarget
    const container = toggle.closest(".choices-group-container")
    const inputs = container
      ? container.querySelectorAll('input[data-check-boxes-toggle-target="input"]')
      : []

    inputs.forEach((i) => {
      if (!i.disabled) i.checked = toggle.checked
    })
    this.updateToggle()
  }
}
