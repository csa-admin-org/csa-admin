import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element"]

  toggle(event) {
    this.elementTargets.forEach((element) => {
      element.classList.toggle("hidden")
      const inputs = element.querySelectorAll("input")
      inputs.forEach((input) => {
        input.disabled = !input.disabled
      })
      const selects = element.querySelectorAll("select")
      selects.forEach((select) => {
        select.disabled = !select.disabled
      })
    })
  }
}
