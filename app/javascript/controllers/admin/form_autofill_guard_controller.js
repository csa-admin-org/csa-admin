import { Controller } from "@hotwired/stimulus"

const UNLOCK =
  "input:not([type=hidden]):not([type=submit]):not([type=button]):not([type=checkbox]):not([type=radio]), textarea"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll(UNLOCK).forEach((el) => {
      if (el.readOnly) return
      if (el.closest(".autofill-sink")) return
      el.readOnly = true
    })
    this.element.addEventListener("focusin", this._unlock)
    this.element.addEventListener("submit", this._excludeSinks)
  }

  disconnect() {
    this.element.removeEventListener("focusin", this._unlock)
    this.element.removeEventListener("submit", this._excludeSinks)
  }

  _unlock = (event) => {
    const el = event.target
    if (!(el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement)) return
    if (!el.readOnly) return
    if (el.closest(".autofill-sink")) return
    el.readOnly = false
  }

  _excludeSinks = () => {
    this.element.querySelectorAll(".autofill-sink input").forEach((el) => {
      el.disabled = true
    })
  }
}
