import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "frame",
    "range",
    "percentageLabel",
    "distributionSource",
    "preset",
    "submit"
  ]

  static values = {
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this._onFrameLoad = this._handleFrameLoad.bind(this)
    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("turbo:frame-load", this._onFrameLoad)
    }
  }

  disconnect() {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("turbo:frame-load", this._onFrameLoad)
    }
    this._cancelDebounce()
  }

  changed(event) {
    this._setDistributionSource(
      event.currentTarget.dataset.distributionSource || this._distributionSource
    )
    this._setPreset("")
    this._debouncedRefresh()
  }

  blurred() {
    if (this._refreshPending || this._debounceTimer) this._refresh()
  }

  mouseLeft(event) {
    if (this._refreshPending || this._debounceTimer) {
      event.currentTarget.blur()
    }
  }

  sliderInput(event) {
    this._setDistributionSource("percentage")
    this._setPreset("")
    this._rebalanceRanges(event.currentTarget)
    this._updatePercentageLabels()
  }

  presetClicked(event) {
    event.preventDefault()
    this._setDistributionSource("total")
    this._setPreset(event.currentTarget.dataset.preset)
    this._refresh()
  }

  formChanged(event) {
    if (event.target.closest("[data-distribution-source]")) return
    this._setDistributionSource("quantity")
    this._setPreset("")
    this._debouncedRefresh()
  }

  _debouncedRefresh() {
    this._cancelDebounce()
    this._debounceTimer = setTimeout(() => this._refresh(), this.debounceValue)
  }

  _cancelDebounce() {
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer)
      this._debounceTimer = null
    }
  }

  _refresh() {
    this._cancelDebounce()
    if (!this.hasFrameTarget) return

    if (this._frameNumberInputFocused()) {
      this._refreshPending = true
      return
    }
    this._refreshPending = false
    this._disableSubmit()

    const url = new URL(window.location.pathname, window.location.origin)
    const searchParams = this._formSearchParams()
    const distributionSource =
      this._distributionSource ||
      (this.hasDistributionSourceTarget ? this.distributionSourceTarget.value : null) ||
      "quantity"
    const preset = this._preset || (this.hasPresetTarget ? this.presetTarget.value : null)

    this._setDistributionSource(distributionSource)
    searchParams.set("distribution_source", distributionSource)

    if (preset) {
      searchParams.set("preset", preset)
      this._preset = null
    } else {
      searchParams.delete("preset")
    }

    url.search = searchParams.toString()
    this.frameTarget.src = url.toString()
  }

  _frameNumberInputFocused() {
    const active = document.activeElement
    return active && active.type === "number" && this.frameTarget.contains(active)
  }

  _setDistributionSource(source) {
    if (!source) return

    this._distributionSource = source
    if (this.hasDistributionSourceTarget) this.distributionSourceTarget.value = source
  }

  _setPreset(preset) {
    this._preset = preset || null
    if (this.hasPresetTarget) this.presetTarget.value = preset || ""
  }

  _handleFrameLoad() {
    this._enableSubmit()
    this._applyAnimations()
  }

  _disableSubmit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }

  _enableSubmit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  _applyAnimations() {
    const animated = this.frameTarget.querySelectorAll(
      ".animate-quantity-update, .animate-surplus-pulse"
    )
    if (animated.length === 0) return

    setTimeout(() => {
      animated.forEach((el) => {
        el.classList.remove("animate-quantity-update", "animate-surplus-pulse")
      })
    }, 700)
  }

  _rebalanceRanges(moved) {
    const movedValue = Math.min(100, Math.max(0, parseFloat(moved.value) || 0))
    moved.value = movedValue

    const others = this.rangeTargets.filter((r) => r !== moved)
    if (others.length === 0) return

    const remaining = Math.round((100 - movedValue) * 100) / 100
    if (remaining <= 0) {
      others.forEach((r) => (r.value = 0))
      return
    }

    const otherTotal = others.reduce((sum, r) => sum + (parseFloat(r.value) || 0), 0)
    const proportions = others.map((r) => {
      const val = parseFloat(r.value) || 0
      return otherTotal > 0 ? (val / otherTotal) * remaining : remaining / others.length
    })

    const rounded = proportions.map((v) => Math.min(100, Math.max(0, Math.round(v * 100) / 100)))
    const roundedSum = rounded.reduce((s, v) => s + v, 0)
    const diff = Math.round((remaining - roundedSum) * 100) / 100
    rounded[rounded.length - 1] = Math.min(100, Math.max(0, rounded[rounded.length - 1] + diff))

    others.forEach((r, i) => (r.value = rounded[i]))
  }

  _updatePercentageLabels() {
    if (!this.hasPercentageLabelTarget) return

    const values = this.rangeTargets.map((r) => Math.round(parseFloat(r.value) || 0))
    const sum = values.reduce((s, v) => s + v, 0)
    const approximate = sum !== 100 && sum !== 0

    this.percentageLabelTargets.forEach((label, i) => {
      const v = values[i] ?? 0
      label.textContent = approximate ? `~${v}%` : `${v}%`
    })
  }

  _formSearchParams() {
    const form = this._formElement()
    if (!form) return new URLSearchParams()

    const formData = new FormData(form)
    this._removeInternalFormFields(formData)

    return new URLSearchParams(formData)
  }

  _formElement() {
    if (this.hasFormTarget) return this.formTarget
    if (typeof HTMLFormElement !== "undefined" && this.element instanceof HTMLFormElement) {
      return this.element
    }
    return this.element.closest("form")
  }

  _removeInternalFormFields(formData) {
    formData.delete("authenticity_token")
    formData.delete("_method")
    formData.delete("utf8")
    formData.delete("commit")
  }
}
