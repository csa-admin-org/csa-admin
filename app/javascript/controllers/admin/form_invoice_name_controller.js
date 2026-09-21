import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["invoice"]
  }

  static get values() {
    return { prefixes: Object }
  }

  connect() {
    this.form.addEventListener("input", this._onFormInput)
    this.apply()
  }

  disconnect() {
    this.form.removeEventListener("input", this._onFormInput)
  }

  get form() {
    return this.element.closest("form")
  }

  apply() {
    this.invoiceTargets.forEach((input) => {
      const match = (input.name || "").match(/\[invoice_name_([a-z]+)\]$/)
      if (!match) return

      const locale = match[1]
      const prefix = this.prefixesValue[locale] || ""
      const publicName = this._value(`public_name_${locale}`)
      const adminName = this._value(`admin_name_${locale}`)
      const name = publicName || adminName
      input.placeholder = name ? `${prefix}: ${name}` : prefix
    })
  }

  _onFormInput = (event) => {
    const name = event.target.name || ""
    if (!/\[(public_name|admin_name)_[a-z]+\]$/.test(name)) return
    this.apply()
  }

  _value(attr) {
    const input = this.form.querySelector(`[name$='[${attr}]']`)
    return input?.value?.trim() || ""
  }
}
