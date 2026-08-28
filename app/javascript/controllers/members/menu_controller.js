import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  show(event) {
    document.body.classList.add("member-menu-open")
    event.preventDefault()
  }

  hide(event) {
    document.body.classList.remove("member-menu-open")
    event.preventDefault()
  }
}
