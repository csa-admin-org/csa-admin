import { Controller } from "@hotwired/stimulus"
import { debounce } from 'throttle-debounce'
import { addClass, removeClass } from "components/utils"

export default class extends Controller {
  static get targets() {
    return ["range", "preset"]
  }

  initialize() {
    this.change = debounce(100, this.change)
  }

  connect() {
    this.updatePresetStates()
  }

  change(event) {
    this.updateLabel(event.target)

    while (this.percentagesDiff() !== 0) {
      this.adjustOtherPercentages(event.target)
    }
    this.updatePresetStates()
  }

  applyPreset(event) {
    const preset = Object.entries(JSON.parse(event.currentTarget.dataset.preset))
    preset.forEach(([inputID, value]) => {
      const input = document.getElementById("basket_size_ids_percentages_" + inputID)
      this.set(input, value)
    })
    this.updatePresetStates()
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

  set(rangeInput, value) {
    rangeInput.value = value
    this.updateLabel(rangeInput)
  }

  updateLabel(target) {
    target.nextElementSibling.innerText = target.value;
  }
}
