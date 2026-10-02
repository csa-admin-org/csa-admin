import { Controller } from "@hotwired/stimulus"

// Depot-limited options stay disabled until that depot is selected.
// Only the selected program's card fieldset is posted. The others stay
// disabled so their required fields cannot block the form.
export default class extends Controller {
  static get targets() {
    return ["card"]
  }

  static get values() {
    return { depotField: String }
  }

  connect() {
    this.form = this.element.closest("form")
    this.onChange = (event) => {
      const target = event.target
      if (target?.name === this.depotFieldValue || this.element.contains(target)) this.filter()
    }
    this.form?.addEventListener("change", this.onChange)
    this.filter()
  }

  disconnect() {
    this.form?.removeEventListener("change", this.onChange)
  }

  filter() {
    const depotId = this.selectedDepotId()
    const inputs = this.element.querySelectorAll('input[type="radio"]')
    let selectedCardId = null

    inputs.forEach((input) => {
      if (!input.value) return

      const depotIds = (input.dataset.depotIds || "").split(",").filter(Boolean)
      const constrained = depotIds.length > 0
      const allowed = !constrained || (depotId && depotIds.includes(depotId))
      input.disabled = !allowed
      input.closest("label, .radio, li")?.classList.toggle("disabled", !allowed)
      if (!allowed && input.checked) input.checked = false
      if (input.checked) selectedCardId = input.dataset.cardId
    })

    this.cardTargets.forEach((card) => {
      const selected = card.dataset.cardId === selectedCardId
      card.classList.toggle("is-hidden", !selected)
      card.disabled = !selected
    })
  }

  selectedDepotId() {
    const name = this.depotFieldValue
    const checked = this.form?.querySelector(`input[name="${name}"]:checked`)
    if (checked) return checked.value

    const select = this.form?.querySelector(`select[name="${name}"]`)
    return select?.value
  }
}
