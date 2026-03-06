import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"
import { listNavigation } from "admin/list_navigation"

export default class extends Controller {
  static targets = ["input", "frame", "form"]
  static values = { currentPage: String }

  initialize() {
    this.submitForm = debounce(200, this.submitForm)
  }

  connect() {
    Object.assign(this, listNavigation())

    // Cache the original sidebar HTML so we can restore it instantly
    // when the search input is cleared (no server round-trip needed).
    this.originalHTML = this.frameTarget.innerHTML
    this.restoring = false

    // Auto-focus the search input when the handbook page loads,
    // but only when there's no anchor so we don't fight the scroll.
    if (!window.location.hash) {
      this.inputTarget.focus()
    }
  }

  search() {
    const query = this.inputTarget.value.trim()

    if (query.length >= 3) {
      this.restoring = false
      this.submitForm()
    } else {
      this.submitForm.cancel({ upcomingOnly: true })
      this.restoring = true
      this.selectedIndex = -1
      this.frameTarget.innerHTML = this.originalHTML
    }
  }

  submitForm() {
    this.formTarget.requestSubmit()
  }

  // Called on turbo:frame-load — if an in-flight response arrives after the
  // menu was already restored, re-apply the original HTML.
  resetSelection() {
    if (this.restoring) {
      this.frameTarget.innerHTML = this.originalHTML
    }
    this.resetListSelection()
  }

  get resultItems() {
    return Array.from(this.frameTarget.querySelectorAll("[data-search-result]"))
  }
}
