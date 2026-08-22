import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value", "year"]
  static values = { years: Array, defaultIndex: Number }

  update(event) {
    this.show(event.detail.index ?? this.defaultIndexValue)
  }

  show(index) {
    if (this.hasYearTarget) {
      this.yearTarget.textContent = this.yearsValue[index]
    }

    this.valueTargets.forEach((element) => {
      const value = JSON.parse(element.dataset.values)[index]
      element.textContent = value ?? "–"
      element.classList.toggle("count-zero", value == null)
    })
  }
}
