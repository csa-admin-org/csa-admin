import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template"]
  static values = {
    threshold: { type: Number, default: 120 }
  }

  connect() {
    this.editors = this.element.querySelectorAll("lexxy-editor")
    if (!this.editors.length || !this.hasTemplateTarget) return

    this._onChange = this._update.bind(this)
    this._warnings = new Map()

    this.editors.forEach((editor) => {
      const warningEl = this.templateTarget.content.cloneNode(true).firstElementChild
      editor.closest(".input")?.appendChild(warningEl)
      this._warnings.set(editor, warningEl)
      editor.addEventListener("lexxy:change", this._onChange)
      editor.addEventListener("lexxy:initialize", this._onChange)
    })

    this._update()
  }

  disconnect() {
    this.editors?.forEach((editor) => {
      editor.removeEventListener("lexxy:change", this._onChange)
      editor.removeEventListener("lexxy:initialize", this._onChange)
    })
    this._warnings?.forEach((warningEl) => warningEl.remove())
    this._warnings?.clear()
  }

  _update() {
    this._warnings?.forEach((warningEl, editor) => {
      const text = editor.toString?.()?.trim() || ""
      const count = text.length > 0 ? text.split(/\s+/).length : 0
      const countEl = warningEl.querySelector("[data-word-count-target='count']")

      if (count > this.thresholdValue) {
        if (countEl) countEl.textContent = count
        warningEl.classList.remove("is-hidden")
      } else {
        warningEl.classList.add("is-hidden")
      }
    })
  }
}
