import { Controller } from "@hotwired/stimulus"

// The paired grant lines stay hidden until a program is selected. Changing
// the program clears typed values and shows that program's catalog defaults
// as placeholders. Empty inputs mean the catalog, not a stored override.
export default class extends Controller {
  static get targets() {
    return ["preview", "error", "choice", "rules", "ruleInput"]
  }

  static get values() {
    return { url: String, membershipId: String }
  }

  connect() {
    this.syncRules(false)
  }

  change() {
    this.syncRules(true)
    this.refresh()
  }

  refresh() {
    if (!this.hasPreviewTarget || !this.urlValue) return

    const url = new URL(this.urlValue, window.location.origin)
    const params = url.searchParams
    if (this.membershipIdValue) params.set("membership_id", this.membershipIdValue)
    params.set("price_reduction_id", this.choiceValue)

    this.ruleInputTargets.forEach((input) => {
      const match = input.name.match(/\[(\w+)\]$/)
      if (match) params.set(match[1], input.value)
    })

    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((payload) => {
        this.previewTarget.textContent = payload.text || ""
        this.previewTarget.classList.toggle("is-hidden", !payload.text)
        this.showError(payload.error || "")
      })
  }

  syncRules(reset) {
    if (!this.hasRulesTarget) return

    const visible = this.choiceValue !== ""
    this.rulesTarget.classList.toggle("is-hidden", !visible)
    if (!reset) return

    this.choiceTarget.closest("li")?.classList.remove("error")
    this.showError("")

    const option = this.choiceTarget.selectedOptions[0]
    this.ruleInputTargets.forEach((input) => {
      const key = input.dataset.formPriceReductionPlaceholder
      input.value = ""
      input.disabled = false
      input.closest("li")?.classList.remove("disabled")
      if (key) input.placeholder = option?.dataset[key] || ""
      input.classList.add("animate-highlight")
    })
    window.setTimeout(() => {
      this.ruleInputTargets.forEach((input) => input.classList.remove("animate-highlight"))
    }, 1000)
  }

  showError(message) {
    if (!this.hasErrorTarget) return

    const item = this.errorTarget.querySelector("li")
    if (item) item.textContent = message
    this.errorTarget.classList.toggle("is-hidden", message === "")
    if (message) {
      this.errorTarget.setAttribute("role", "alert")
      this.choiceTarget.closest("li")?.classList.add("error")
    } else {
      this.errorTarget.removeAttribute("role")
      this.choiceTarget.closest("li")?.classList.remove("error")
    }
  }

  get choiceValue() {
    return this.hasChoiceTarget ? this.choiceTarget.value : ""
  }
}
