import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"
import { addClass, removeClass, show, hide } from "components/utils"

export default class extends Controller {
  static get targets() {
    return [
      "mode",
      "range",
      "input",
      "sum",
      "preset",
      "basketQuantity",
      "quantity"
    ]
  }

  initialize() {
    this.change = debounce(100, this.change)
  }

  connect() {
    this.updateAll()

    // Ensure correct mode is selected on page load
    const anchor = window.location.hash
    if (anchor == "#manual" && this.modeTarget.value == "automatic") {
      document.querySelector('a[aria-controls="manual"]').click()
    } else if (anchor == "#automatic" && this.modeTarget.value == "manual") {
      document.querySelector('a[aria-controls="automatic"]').click()
    }
  }

  automaticMode(_event) {
    this.modeTarget.value = "automatic"
    this.quantityTarget.required = true
    this.quantityTarget.disabled = false
    this.basketQuantityTargets.forEach((input) => {
      input.required = false
      input.disabled = true
    })
  }

  manualMode(_event) {
    this.modeTarget.value = "manual"
    this.quantityTarget.required = false
    this.quantityTarget.disabled = true
    this.basketQuantityTargets.forEach((input) => {
      input.required = true
      input.disabled = false
    })
  }

  change(event) {
    this.updateOther(event.target)

    if (event.target.type == "range") {
      while (this.percentagesDiff() !== 0) {
        this.adjustOtherPercentages(event.target)
      }
    }
    this.updateAll()
  }

  applyPreset(event) {
    const preset = Object.entries(
      JSON.parse(event.currentTarget.dataset.preset)
    )
    preset.forEach(([inputID, value]) => {
      const input = document.getElementById(
        "basket_size_ids_percentages_" + inputID
      )
      this.set(input, value)
    })
    this.updateAll()
  }

  updatePresetStates() {
    this.presetTargets.forEach((p) => {
      const preset = Object.entries(JSON.parse(p.dataset.preset))
      const matchCurrentPercentages = preset.every(([inputID, value]) => {
        const input = document.getElementById(
          "basket_size_ids_percentages_" + inputID
        )
        return input && parseInt(input.value) == value
      })
      p.disabled = matchCurrentPercentages
    })
  }

  percentagesDiff() {
    return this.rangeTargets.reduce((s, t) => s + parseInt(t.value), 0) - 100
  }

  adjustOtherPercentages(target) {
    const otherRangeTargets = this.otherRangeTargets(target)
    let n = otherRangeTargets.length
    let diff = this.percentagesDiff()

    otherRangeTargets.forEach((t) => {
      let d = Math.round(diff / n)
      this.set(t, parseInt(t.value) - d)
      diff = diff - d
      n = n - 1
    })
  }

  otherRangeTargets(target) {
    let targets = this.rangeTargets.filter((t) => {
      return target.name !== t.name && parseInt(t.value) !== 0
    })
    if (targets.length === 0) {
      targets = this.rangeTargets.filter((t) => {
        return target.name !== t.name
      })
    }
    return targets
  }

  set(target, value) {
    target.value = value
    this.updateOther(target)
  }

  updateOther(target) {
    if (target.type == "range") {
      const input = document.getElementById(target.id.replace("_range", ""))
      if (input) {
        input.value = target.value
      }
    } else {
      const range = document.getElementById(target.id + "_range")
      if (range) {
        range.value = target.value
      }
    }
  }

  updateRangeStates() {
    const sum = this.percentagesSum()
    this.rangeTargets.forEach((t) => {
      t.disabled = sum !== 100
    })
  }

  updateSum() {
    const sum = this.percentagesSum()
    if (sum > 100) {
      this.sumTarget.innerHTML = "-" + (sum - 100)
    } else if (sum < 100) {
      this.sumTarget.innerHTML = "+" + (100 - sum)
    }
    if (sum === 100) {
      hide(this.sumTarget)
    } else {
      show(this.sumTarget)
    }
  }

  percentagesSum() {
    return this.inputTargets.reduce((s, t) => s + parseInt(t.value), 0)
  }

  updateAll() {
    this.updatePresetStates()
    this.updateRangeStates()
    this.updateSum()
  }
}
