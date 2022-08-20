import { Controller } from "@hotwired/stimulus"
import { removeValues } from "components/utils"

export default class extends Controller {
  static targets = ["input"]

  reset() {
    removeValues(this.inputTargets)
  }
}
