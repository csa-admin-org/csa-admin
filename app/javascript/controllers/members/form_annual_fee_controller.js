import { Controller } from "@hotwired/stimulus"
import { prop, addClass, removeClass } from "components/utils"

export default class extends Controller {
  connect() {
    this.wrapper = this.element.querySelector(".input.member_annual_fee")
    this.input = this.element.querySelector(".member_annual_fee input")
  }

  enableInput() {
    if (!this.input) return

    removeClass(this.wrapper, "disabled")
    prop(this.input, "disabled", false)
    this.input.value = this.input.dataset.defaultValue
  }

  disableInput() {
    if (!this.input) return

    addClass(this.wrapper, "disabled")
    prop(this.input, "disabled", true)
    this.input.value = this.input.dataset.disabledValue
  }
}
