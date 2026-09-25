import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

export default class extends Controller {
  static get targets() {
    return ["frame", "payload"]
  }

  static get values() {
    return {
      url: String,
      startMonth: Number,
      currentYear: Number,
      yearTemplate: String
    }
  }

  initialize() {
    this.refresh = debounce(200, this._refresh.bind(this))
  }

  connect() {
    this.form.addEventListener("input", this._onForm)
    this.form.addEventListener("change", this._onForm)
    this.form.addEventListener("click", this._onClick)
    this._applyPayload()
  }

  disconnect() {
    this.refresh.cancel()
    this.form.removeEventListener("input", this._onForm)
    this.form.removeEventListener("change", this._onForm)
    this.form.removeEventListener("click", this._onClick)
  }

  payloadTargetConnected() {
    this._applyPayload()
  }

  get form() {
    return this.element.closest("form")
  }

  get dateInput() {
    return this.form?.querySelector("#delivery_date")
  }

  get submitButton() {
    return this.form?.querySelector("button[type=submit]")
  }

  _refresh() {
    if (!this.hasFrameTarget || !this.hasUrlValue) return

    if (this._uniqueDateSelected()) {
      this._applyLocal(this.dateInput.value)
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("date", this.dateInput.value)
      Turbo.visit(url, { frame: this.frameTarget.id })
      return
    }

    if (!this._bulkSelected()) {
      this._clear()
      return
    }

    const params = this._bulkParams()
    if (!params) {
      this._clearBulk()
      return
    }

    this._applyBulkLocal(params)
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("bulk_dates_starts_on", params.starts)
    url.searchParams.set("bulk_dates_ends_on", params.ends)
    url.searchParams.set("bulk_dates_weeks_frequency", params.frequency)
    params.wdays.forEach((wday) => url.searchParams.append("bulk_dates_wdays[]", wday))
    Turbo.visit(url, { frame: this.frameTarget.id })
  }

  _clear() {
    if (this.hasPayloadTarget) {
      this.payloadTarget.textContent = ""
      this.payloadTarget.dataset.confirm = ""
      this.payloadTarget.dataset.bulkConfirm = ""
    }
    this._applyPayload()
  }

  _clearBulk() {
    if (!this.hasPayloadTarget) return
    this.payloadTarget.dataset.bulkConfirm = ""
    this.payloadTarget.dataset.bulkFor = ""
    this._applyPayload()
  }

  _applyLocal(iso) {
    const fiscalYear = this._fiscalYear(iso)
    if (!fiscalYear || !this.hasPayloadTarget) return

    this.payloadTarget.textContent = this.yearTemplateValue.replace("__YEAR__", fiscalYear.label)
    if (fiscalYear.year !== this.currentYearValue || this.payloadTarget.dataset.forDate !== iso) {
      this.payloadTarget.dataset.confirm = ""
    }
    this._applyPayload()
  }

  _applyBulkLocal(params) {
    if (!this.hasPayloadTarget) return
    const fiscalYear = this._fiscalYear(params.starts)
    if (
      !fiscalYear ||
      fiscalYear.year !== this.currentYearValue ||
      this.payloadTarget.dataset.bulkFor !== params.key
    ) {
      this.payloadTarget.dataset.bulkConfirm = ""
    }
    this._applyPayload()
  }

  _bulkParams() {
    const starts = this.form.querySelector("#delivery_bulk_dates_starts_on")?.value
    const ends = this.form.querySelector("#delivery_bulk_dates_ends_on")?.value
    const frequency = this.form.querySelector("#delivery_bulk_dates_weeks_frequency")?.value
    const wdays = Array.from(
      this.form.querySelectorAll("#delivery_bulk_dates_wdays_input input:checked")
    ).map((input) => input.value)
    if (!starts || !ends || !frequency || wdays.length === 0) return null

    return {
      starts,
      ends,
      frequency,
      wdays,
      key: [starts, ends, frequency, wdays.slice().sort().join("-")].join("|")
    }
  }

  _fiscalYear(iso) {
    const [year, month] = iso.split("-").map(Number)
    if (!year || !month) return null

    const start = this.startMonthValue || 1
    const fyYear = month >= start ? year : year - 1
    const label =
      start === 1 ? String(fyYear) : `${fyYear}-${String((fyYear + 1) % 100).padStart(2, "0")}`
    return { year: fyYear, label }
  }

  _applyPayload() {
    const button = this.submitButton
    if (!button) return

    const payload = this.hasPayloadTarget ? this.payloadTarget.dataset : {}
    const confirm = this._uniqueDateSelected()
      ? payload.confirm
      : this._bulkSelected()
        ? payload.bulkConfirm
        : ""
    if (confirm) {
      button.setAttribute("data-confirm", confirm)
    } else {
      button.removeAttribute("data-confirm")
    }
  }

  _uniqueDateSelected() {
    const input = this.dateInput
    if (!input || input.disabled || !input.value) return false

    const tab = this.form?.querySelector('[aria-controls="unique_date"]')
    return !tab || tab.getAttribute("aria-selected") === "true"
  }

  _bulkSelected() {
    const tab = this.form?.querySelector('[aria-controls="bulk_dates"]')
    return tab?.getAttribute("aria-selected") === "true"
  }

  _onForm = (event) => {
    const name = event.target.name || ""
    if (!name.includes("[date]") && !name.includes("[bulk_dates_")) return
    this.refresh()
  }

  _onClick = () => {
    queueMicrotask(() => this._applyPayload())
    this.refresh()
  }
}
