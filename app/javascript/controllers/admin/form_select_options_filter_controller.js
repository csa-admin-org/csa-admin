import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { attribute: String }
  }
  static get targets() {
    return ["select"]
  }

  filter(event) {
    this.selectTarget.removeAttribute("disabled");
    Array.from(this.selectTarget.options).forEach((option) => {
      if (option.getAttribute(this.attributeValue) === event.currentTarget.value) {
        option.disabled = option.getAttribute("data-disabled") == "true";
        option.hidden = option.getAttribute("data-disabled") == "true";
        option.selected = option.getAttribute("data-disabled") == "true";
      } else {
        option.disabled = true;
        option.hidden = true;
        option.selected = false;
      }
    });
    Array.from(this.selectTarget.options).find((o) => !o.disabled).selected = true;
  }
}
