import { Controller } from "@hotwired/stimulus"
import { show } from "components/utils"

export default class extends Controller {
  static targets = ["form", "warningMessage"]

  connect() {
    this.localStorageKey = `lexxy:${window.location}`
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
    const editors = new Set()

    this.formTarget.querySelectorAll("lexxy-editor[name]").forEach((editor) => {
      editors.add(editor.getAttribute("name"))
      if (!editor.isEmpty) data.push([editor.getAttribute("name"), editor.value])
    })

    for (var pair of form.entries()) {
      if (pair[0] == "authenticity_token" || editors.has(pair[0])) continue
      if (pair[1]) data.push([pair[0], pair[1]])
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
        let editor = this.#editor(name)
        if (editor) {
          editor.value = value
          return
        }

        let input = form.querySelector(`[name='${CSS.escape(name)}']`)
        if (input) {
          input.value = value
          // Wait for other Stimulus controllers loading before triggering a change event.
          setTimeout(() => {
            this.dispatch("change", { target: input, prefix: false })
          }, 100)
        }
      })
    }
  }

  #editor(name) {
    return this.formTarget.querySelector(`lexxy-editor[name='${CSS.escape(name)}']`)
  }
}
