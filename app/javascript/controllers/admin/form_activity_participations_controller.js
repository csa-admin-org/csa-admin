import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

const PREVIEW_PARAM =
  /\[(member_id|basket_size_id|waiting_basket_size_id|basket_quantity|depot_id|waiting_depot_id|delivery_cycle_id|waiting_delivery_cycle_id|started_on|ended_on|waiting_membership_started_on|activity_participations_demanded_annually|waiting_activity_participations_demanded_annually|salary_basket)\]$|\[(memberships_basket_complements_attributes|members_basket_complements_attributes)\]/

export default class extends Controller {
  static get targets() {
    return ["annually", "demanded", "priceChange", "frame", "payload"]
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
    if (this.hasAnnuallyTarget) {
      this.annuallyTarget.placeholder = payload.defaultAnnually ?? ""
    }
    if (this.hasDemandedTarget) {
      this.demandedTarget.value = payload.demanded ?? ""
    }
    if (this.hasPriceChangeTarget) {
      this.priceChangeTarget.placeholder = payload.defaultPriceChange ?? ""
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
    if (this.hasPriceChangeTarget && event.target === this.priceChangeTarget) return
    this.refresh()
  }

  _onFormClick = (event) => {
    if (!event.target.closest(".has-many-remove")) return

    queueMicrotask(() => this.refresh())
  }
}
