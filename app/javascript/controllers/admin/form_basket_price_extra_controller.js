import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

const PREVIEW_PARAM =
  /\[(basket_price_extra|waiting_basket_price_extra|price_extra|basket_size_id|waiting_basket_size_id|basket_size_price|started_on|waiting_membership_started_on)\]$|\[(memberships_basket_complements_attributes|members_basket_complements_attributes|baskets_basket_complements_attributes)\]/

export default class extends Controller {
  static get targets() {
    return ["extra", "billedExtra", "frame", "payload"]
  }

  static get values() {
    return { url: String, year: Number }
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
    if (this.hasBilledExtraTarget) {
      this.billedExtraTarget.value = payload.billedExtra ?? ""
    }
  }

  _refresh() {
    if (!this.hasFrameTarget || !this.hasUrlValue || !this.form) return

    const params = new URLSearchParams()
    for (const [key, value] of new FormData(this.form).entries()) {
      if (PREVIEW_PARAM.test(key)) params.append(key, value)
    }
    if (this.hasYearValue) params.append("year", String(this.yearValue))
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
    if (this.hasExtraTarget && event.target === this.extraTarget) return
    this.refresh()
  }

  _onFormClick = (event) => {
    if (!event.target.closest(".has-many-remove")) return

    queueMicrotask(() => this.refresh())
  }
}
