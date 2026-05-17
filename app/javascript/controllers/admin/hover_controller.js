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
    const targets = document.querySelectorAll(`[data-hover-id="${this.idValue}"]`)
    targets.forEach((el) => {
      if (hovering) {
        el.classList.add(...this.classValue)
      } else {
        el.classList.remove(...this.classValue)
      }
    })
  }
}
