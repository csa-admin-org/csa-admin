import { Controller } from "@hotwired/stimulus"
import { removeValues } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  reset() {
    removeValues(this.inputTargets)
  }
}
