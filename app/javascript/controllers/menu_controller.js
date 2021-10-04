import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._hideMenu()
  }

  show(event) {
    this.menuTarget.setAttribute("aria-expanded", "true")
    event.preventDefault()
  }

  hide(event) {
    this._hideMenu()
    event.preventDefault()
  }

  _hideMenu() {
    if (this.menuTarget.getAttribute("aria-expanded") == "true") {
      this.menuTarget.setAttribute("aria-expanded", "false")
    }
  }
}
