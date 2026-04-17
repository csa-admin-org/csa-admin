import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.observers = []
    this.element
      .querySelectorAll(".formtastic fieldset.actions")
      .forEach((fieldset) => this.observe(fieldset))
  }

  disconnect() {
    this.observers.forEach(({ observer, sentinel }) => {
      observer.disconnect()
      sentinel.remove()
    })
    this.observers = []
  }

  observe(fieldset) {
    const sentinel = document.createElement("div")
    sentinel.setAttribute("aria-hidden", "true")
    sentinel.style.height = "1px"
    sentinel.style.pointerEvents = "none"
    fieldset.after(sentinel)

    const observer = new IntersectionObserver(([entry]) => {
      fieldset.classList.toggle("is-stuck", !entry.isIntersecting)
    })
    observer.observe(sentinel)
    this.observers.push({ observer, sentinel })
  }
}
