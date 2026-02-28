import { Controller } from "@hotwired/stimulus"
import { checked, prop, addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  connect() {
    for (const input of this.inputTargets) {
      if (input.tagName === "SELECT") {
        this.#limitSelectOptions(input)
      } else if (input.disabled) {
        const label = `label[for='${input.id}']`
        addClass(label, "disabled")
      }
    }
  }

  limitChoices(event) {
    if (!this.hasInputTarget || !event.params.values) return

    const values = event.params.values.toString().split(",")
    for (const input of this.inputTargets) {
      if (input.tagName === "SELECT") {
        this.#limitSelectOptions(input, values)
      } else {
        const label = `label[for='${input.id}']`
        if (values.includes(input.value)) {
          removeClass(label, "disabled")
          prop(input, "disabled", false)
        } else {
          addClass(label, "disabled")
          checked(input, false)
          prop(input, "disabled", true)
        }
      }
    }

    const radios = Array.from(this.inputTargets).filter(
      (i) => i.tagName !== "SELECT"
    )
    if (radios.length > 0) {
      checked(
        radios.find((i) => !i.disabled),
        true
      )
    }
  }

  #limitSelectOptions(select, values) {
    let hasSelectedValid = false
    for (const option of select.options) {
      if (!option.value) continue // skip blank prompt
      const allowed = !values || values.includes(option.value)
      option.disabled = !allowed
      if (!allowed && option.selected) {
        option.selected = false
      }
      if (allowed && option.selected) {
        hasSelectedValid = true
      }
    }
    if (!hasSelectedValid) {
      const firstEnabled = Array.from(select.options).find(
        (o) => o.value && !o.disabled
      )
      if (firstEnabled) firstEnabled.selected = true
    }
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
