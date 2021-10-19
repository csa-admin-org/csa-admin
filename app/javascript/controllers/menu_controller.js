import { Controller } from "@hotwired/stimulus"
import { addClass, removeClass } from "components/utils"

export default class extends Controller {
  static targets = ["menu", "body"]

  show(event) {
    removeClass(this.menuTargets, "hidden")
    addClass(this.bodyTargets, "hidden")
    event.preventDefault()
  }

  hide(event) {
    addClass(this.menuTargets, "hidden")
    removeClass(this.bodyTargets, "hidden")
    event.preventDefault()
  }
}
