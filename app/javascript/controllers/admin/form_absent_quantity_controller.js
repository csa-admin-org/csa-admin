import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { message: String }
  }

  connect() {
    this.onSubmit = this.confirm.bind(this)
    this.form?.addEventListener("submit", this.onSubmit)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.onSubmit)
  }

  confirm(event) {
    const input = this.form?.querySelector("#basket_quantity")
    if (!input || input.disabled || Number(input.value) <= 0) return
    if (window.confirm(this.messageValue)) return

    event.preventDefault()
    event.stopPropagation()
  }

  get form() {
    return this.element.closest("form")
  }
}
