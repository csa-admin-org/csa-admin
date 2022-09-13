import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { with: String }
  }

  connect() {
    this.element.dataset['action'] = 'submit->disable#disableForm'
    if (!this.hasWithValue) {
      this.withValue = "Processing..."
    }
  }

  disableForm() {
    this._submitButtons().forEach(button => {
      button.disabled = true
      button.innerHTML = this.withValue
    })
  }

  _submitButtons() {
    return this.element.querySelectorAll("[type='submit']")
  }
}
