import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { id: String }
  }

  show() {
    this._toggleHover(true)
  }

  hide() {
    this._toggleHover(false)
  }

  _toggleHover(hovering) {
    const targets = document.querySelectorAll(
      `[data-hover-id="${this.idValue}"]`
    )
    targets.forEach((el) => {
      hovering ? el.classList.add("hovered") : el.classList.remove("hovered")
    })
  }
}
