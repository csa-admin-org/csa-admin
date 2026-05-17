import { Controller } from "@hotwired/stimulus"
import { prop, removeValues } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["input", "select"]
  }

  connect() {
    if (this.hasSelectTarget) this.update(this.selectTarget)
  }

  change(event) {
    this.update(event.target)
  }

  update(select) {
    if (select.value === "0") {
      prop(this.inputTargets, "disabled", false)
      removeValues(this.inputTargets)
    } else {
      prop(this.inputTargets, "disabled", true)
      this.setInputValues(select.selectedOptions[0])
    }
  }

  setInputValues(option) {
    for (const input of this.inputTargets) {
      input.value = this.valueFor(input, option)
    }
  }

  valueFor(input, option) {
    const values = JSON.parse(option.getAttribute(this.dataAttributeFor(input)) || "{}")
    return values[this.localeFor(input)] || ""
  }

  dataAttributeFor(input) {
    return `data-${input.dataset.presetAttribute.replaceAll("_", "-")}`
  }

  localeFor(input) {
    return input.name.match(/_([a-z]{2})\]$/)[1]
  }
}
