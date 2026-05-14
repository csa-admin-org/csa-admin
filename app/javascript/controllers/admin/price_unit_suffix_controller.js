import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "text"]
  static values = { suffixes: Object }

  connect() {
    this.update()
  }

  update() {
    const unit = this.selectTarget.value
    this.textTarget.textContent = this.suffixesValue[unit] || ""
  }
}
