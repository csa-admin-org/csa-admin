import { Controller } from "@hotwired/stimulus"
import { prop, removeValues, setValues } from "components/utils"

export default class extends Controller {
  static targets = ["input"]

  change(event) {
    if (event.target.value === "0") {
      prop(this.inputTargets, "disabled", false)
      removeValues(this.inputTargets)
    } else {
      prop(this.inputTargets, "disabled", true)
      setValues(this.inputTargets, "preset")
    }
  }
}
