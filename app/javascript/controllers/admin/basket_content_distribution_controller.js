import { Controller } from "@hotwired/stimulus"
import { debounce } from 'throttle-debounce'
import { addClass, removeClass, show, hide } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["range", "input", "sum", "preset", "quantityInput"]
  }

  initialize() {
    this.change = debounce(100, this.change)
  }

  connect() {
    this.updateAll()
  }

  automaticMode(_event) {
    this.presetTargets[0].click()
    this.quantityInputTargets.forEach((input) => {
      input.value = ""
    })
  }

  manualMode(_event) {
    this.quantityInputTargets.forEach((input) => {
      input.value = 0
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
    const preset = Object.entries(JSON.parse(event.currentTarget.dataset.preset))
    preset.forEach(([inputID, value]) => {
      const input = document.getElementById("basket_size_ids_percentages_" + inputID)
      this.set(input, value)
    })
    this.updateAll()
  }

  updatePresetStates() {
    this.presetTargets.forEach((p) => {
      const preset = Object.entries(JSON.parse(p.dataset.preset))
      const matchCurrentPercentages = preset.every(([inputID, value]) => {
        const input = document.getElementById("basket_size_ids_percentages_" + inputID)
        return input.value == value
      })
      if (matchCurrentPercentages) {
        addClass(p, "disabled")
      } else {
        removeClass(p, "disabled")
      }
    })
  }

  percentagesDiff() {
    return (this.rangeTargets.reduce((s, t) => s + parseInt(t.value), 0) - 100)
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
    if(targets.length === 0) {
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
      input.value = target.value
    } else {
      const range = document.getElementById(target.id + "_range")
      range.value = target.value
    }
  }

  updateRangeStates() {
    const sum = this.percentagesSum()
    this.rangeTargets.forEach((t) => {
      t.disabled = (sum !== 100)
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
