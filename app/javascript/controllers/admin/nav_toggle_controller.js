import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    document.body.classList.toggle("admin-nav-open")
    const expanded = event.currentTarget.getAttribute("aria-expanded") === "true"
    event.currentTarget.setAttribute("aria-expanded", !expanded)
  }
}
