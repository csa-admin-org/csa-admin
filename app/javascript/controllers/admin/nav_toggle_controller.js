import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle(event) {
    this.menuTarget.classList.toggle("hidden")
    const expanded = event.currentTarget.getAttribute("aria-expanded") === "true"
    event.currentTarget.setAttribute("aria-expanded", !expanded)
  }
}
