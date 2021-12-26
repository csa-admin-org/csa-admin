import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "input"]

  connect() {
    this.updateToggle()
  }

  updateToggle() {
    this.toggleTarget.checked = this.inputTargets.every(i => i.checked)
  }

  toggleAll() {
    this.inputTargets.forEach(i => i.checked = this.toggleTarget.checked)
  }
}
