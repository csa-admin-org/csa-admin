import { Controller } from "@hotwired/stimulus"
import { removeClass, hide } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["elements"]
  }

  showAll(event) {
    event.preventDefault()
    removeClass(this.elementsTarget, "partially-hidden")
    hide(event.target)
  }
}
