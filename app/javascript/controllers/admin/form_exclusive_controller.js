import { Controller } from "@hotwired/stimulus"

// One filled input clears and disables the others. Both stay editable when
// none, or more than one, already have a value, so a bad record can be fixed.
// Disabled inputs are re-enabled on submit so the cleared value is posted.
export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  connect() {
    this.form = this.element.closest("form")
    // Capture on window so this runs before Turbo reads FormData.
    this.onSubmit = (event) => {
      if (event.target !== this.form) return

      this.release()
    }
    window.addEventListener("submit", this.onSubmit, true)
    this.sync()
  }

  disconnect() {
    window.removeEventListener("submit", this.onSubmit, true)
  }

  sync() {
    const filled = this.inputTargets.filter((input) => input.value !== "")
    if (filled.length !== 1) {
      this.release()
      return
    }

    this.inputTargets.forEach((input) => {
      const disable = input !== filled[0]
      if (disable) input.value = ""
      input.disabled = disable
      input.closest("li")?.classList.toggle("disabled", disable)
    })
  }

  release() {
    this.inputTargets.forEach((input) => {
      input.disabled = false
      input.closest("li")?.classList.remove("disabled")
    })
  }
}
