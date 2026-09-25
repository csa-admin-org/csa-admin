import { Controller } from "@hotwired/stimulus"

// A selected period replaces the per-order delay. A disabled input is not
// submitted, so the mirror keeps the stored number.
export default class extends Controller {
  static get targets() {
    return ["period", "delay", "mirror"]
  }

  static get values() {
    return { manualHint: String, groupedHint: String }
  }

  connect() {
    this.sync()
  }

  sync() {
    const grouped = this.periodTarget.value !== ""
    this.mirrorTarget.value = this.delayTarget.value
    this.delayTarget.disabled = grouped
    this.mirrorTarget.disabled = !grouped

    const hint = this.delayTarget.closest("li")?.querySelector(".inline-hints")
    if (!hint) return

    hint.textContent = grouped ? this.groupedHintValue : this.manualHintValue
  }
}
