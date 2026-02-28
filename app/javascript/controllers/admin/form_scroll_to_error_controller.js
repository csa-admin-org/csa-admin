import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const error =
      this.element.querySelector("[role='alert']") ||
      this.element.querySelector(".field_with_errors")
    if (error) {
      setTimeout(() => error.scrollIntoView({ behavior: "smooth", block: "center" }), 100)
    }
  }

  observeForms() {
    const forms = document.querySelectorAll("form.formtastic")
    forms.forEach((form) => {
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (
            mutation.type === "attributes" &&
            mutation.attributeName === "aria-busy"
          ) {
            if (!form.hasAttribute("aria-busy")) {
              this.observeFormChanges(form)
              observer.disconnect()
            }
          }
        })
      })

      observer.observe(form, { attributes: true })
    })
  }

  observeFormChanges(form) {
    this.scroll(form)
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === "childList" && mutation.addedNodes.length > 0) {
          this.scroll(form)
          observer.disconnect()
        }
      })
    })
    observer.observe(form, { childList: true, subtree: true })
  }

  scroll(form) {
    let error = form.querySelector(".field_with_errors")
    if (error) {
      error.scrollIntoView({ behavior: "smooth", block: "center" })
    }
  }
}
