import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { message: String }
  }

  confirm(event) {
    if (!window.confirm(this.messageValue)) {
      event.preventDefault()
    }
  }
}
