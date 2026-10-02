import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["type", "name", "number", "expiresOn"]
  }

  connect() {
    this.toggle()
  }

  toggle() {
    const option = this.typeTarget.selectedOptions[0]
    const selected = this.typeTarget.value
    this.#field(this.nameTarget, selected && option?.dataset.requireName === "true")
    this.#field(this.numberTarget, selected && option?.dataset.requireNumber === "true")
    this.#field(this.expiresOnTarget, selected && option?.dataset.requireExpiresOn === "true")
  }

  #field(wrapper, visible) {
    wrapper.classList.toggle("is-hidden", !visible)
    wrapper.querySelectorAll("input, select").forEach((input) => {
      input.disabled = !visible
      input.required = visible
    })
  }
}
