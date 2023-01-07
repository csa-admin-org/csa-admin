import { Controller } from "@hotwired/stimulus"
import { show, hide } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["element"]
  }

  toggle(event) {
    const selectedId = event.target.value
    this.elementTargets.forEach(el => {
      if (el.dataset.elementId == selectedId) {
        show(el)
      } else {
        hide(el)
      }
    })
  }
}
