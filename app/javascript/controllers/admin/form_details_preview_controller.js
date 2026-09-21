import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

const PREVIEW_PARAM =
  /\[(price|activity_price|activity_participations_form_min|activity_participations_form_max|activity_participations_demanded_annually|shares_number|first_cweek|last_cweek|street|zip|city|absences_included_annually|week_numbers|exclude_cweek_range|public_name_[a-z]+)\]$|\[(current_delivery_ids|future_delivery_ids|delivery_cycle_ids|wdays|periods_attributes)\]/

export default class extends Controller {
  static get targets() {
    return ["input", "frame", "payload"]
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
    this.form.addEventListener("click", this._onFormClick)
  }

  disconnect() {
    this.refresh.cancel()
    this.form.removeEventListener("input", this._onFormInput)
    this.form.removeEventListener("change", this._onFormChange)
    this.form.removeEventListener("click", this._onFormClick)
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
    this.inputTargets.forEach((input) => {
      const match = (input.name || "").match(/form_detail_([a-z]+)\]$/)
      if (!match) return

      const locale = match[1]
      const key = `placeholder${locale.charAt(0).toUpperCase()}${locale.slice(1)}`
      input.placeholder = payload[key] ?? ""
    })
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
    const name = event.target.name || ""
    if (!PREVIEW_PARAM.test(name)) return
    this.refresh()
  }

  _onFormChange = (event) => {
    const name = event.target.name || ""
    if (!PREVIEW_PARAM.test(name)) return
    this.refresh()
  }

  _onFormClick = (event) => {
    if (!event.target.closest(".has-many-remove")) return

    queueMicrotask(() => this.refresh())
  }
}
