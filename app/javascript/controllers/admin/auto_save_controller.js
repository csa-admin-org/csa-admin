import { Controller } from "@hotwired/stimulus"
import { show } from "components/utils"

export default class extends Controller {
  static targets = ["form", "warningMessage"];

  connect() {
    this.localStorageKey = window.location
    this.setFormData()
  }

  clearLocalStorage() {
    if (localStorage.getItem(this.localStorageKey) != null) {
      localStorage.removeItem(this.localStorageKey)
    }
  }

  getFormData() {
    const form = new FormData(this.formTarget)
    let data = []

    for (var pair of form.entries()) {
      if (pair[0] != "authenticity_token") {
        let editor = this.formTarget.querySelector(`[name='${pair[0]}'] ~ trix-editor`)
        if (editor) {
          data.push([pair[0], JSON.stringify(editor.editor)])
        }
        else {
          data.push([pair[0], pair[1]])
        }
      }
    }

    return Object.fromEntries(data)
  }

  saveToLocalStorage() {
    const data = this.getFormData()
    localStorage.setItem(this.localStorageKey, JSON.stringify(data))
  }

  setFormData() {
    if (localStorage.getItem(this.localStorageKey) != null) {
      show(this.warningMessageTarget)
      const data = JSON.parse(localStorage.getItem(this.localStorageKey))
      const form = this.formTarget
      Object.entries(data).forEach((entry) => {
        let name = entry[0]
        let value = entry[1]
        let input = form.querySelector(`[name='${name}']`)
        if (input) {
          let editor = form.querySelector(`[name='${name}'] ~ trix-editor`)
          if (editor) {
            editor.editor.loadJSON(JSON.parse(value))
          } else {
            input.value = value
            // Wait for other Stimulus controllers loading before triggering a change event.
            setTimeout(() => {
              this.dispatch('change', { target: input, prefix: false })
            }, 100)
          }
        }
      })
    }
  }
}
