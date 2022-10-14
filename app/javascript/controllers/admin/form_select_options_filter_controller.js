import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { attribute: String }
  }
  static get targets() {
    return ["select"]
  }

  filter(event) {
    this.selectTargets.forEach(select => {
      select.removeAttribute("disabled")
      const selectedValue = select.value
      Array.from(select.options).forEach((option) => {
        const values = option.getAttribute(this.attributeValue)?.split(',')
        if (values && values.some((v) => v === event.currentTarget.value.toString())) {
          option.disabled = option.getAttribute("data-disabled") == "true"
          option.hidden = option.getAttribute("data-disabled") == "true"
          option.selected = option.getAttribute("data-disabled") == "true"
        } else {
          option.disabled = true
          option.hidden = true
          option.selected = false
        }
        if (option.value === selectedValue && !option.disabled) {
          option.selected = true;
        }
      })
      if (!select.value) {
        Array.from(select.options).find((o) => !o.disabled).selected = true
      }
    })
  }
}
