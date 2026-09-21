import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

const PREVIEW_PARAM =
  /\[(delivery_cycle_id|started_on|ended_on|absences_included_annually|basket_size_id|depot_id)\]$/

export default class extends Controller {
  static get targets() {
    return ["annually", "included", "frame", "payload"]
  }

  static get values() {
    return { url: String }
  }

  initialize() {
    this.refresh = debounce(250, this._refresh.bind(this))
  }

  connect() {
    this.form.addEventListener("input", this._onFormInput)
    this.form.addEventListener("change", this._onFormChange)
  }

  disconnect() {
    this.refresh.cancel()
    this.form.removeEventListener("input", this._onFormInput)
    this.form.removeEventListener("change", this._onFormChange)
  }

  get form() {
    return this.element.closest("form")
  }

  payloadTargetConnected() {
    this.apply()
  }

  apply() {
    if (!this.hasPayloadTarget) return

    const payload = this.payloadTarget.dataset
    if (this.hasAnnuallyTarget) {
      this.annuallyTarget.placeholder = payload.defaultAnnually ?? ""
    }
    if (this.hasIncludedTarget) {
      this.includedTarget.value = payload.included ?? ""
    }
  }

  _refresh() {
    if (!this.hasFrameTarget || !this.hasUrlValue || !this.form) return

    const params = new URLSearchParams()
    for (const [key, value] of new FormData(this.form).entries()) {
      if (PREVIEW_PARAM.test(key)) params.append(key, value)
    }
    const url = new URL(this.urlValue, window.location.origin)
    url.search = params.toString()
    Turbo.visit(url, { frame: this.frameTarget.id })
  }

  _onFormInput = (event) => {
    if (!this.hasAnnuallyTarget || event.target !== this.annuallyTarget) return
    this.refresh()
  }

  _onFormChange = (event) => {
    if (this.hasAnnuallyTarget && event.target === this.annuallyTarget) return
    this.refresh()
  }
}
