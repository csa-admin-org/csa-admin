import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: String,
    class: { type: Array, default: ["hovered"] }
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
      hovering
        ? el.classList.add(...this.classValue)
        : el.classList.remove(...this.classValue)
    })
  }
}
