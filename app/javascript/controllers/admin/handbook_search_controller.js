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

    // Auto-focus the search input when the handbook page loads,
    // but only when there's no anchor so we don't fight the scroll.
    if (!window.location.hash) {
      this.inputTarget.focus()
    }
  }

  search() {
    const query = this.inputTarget.value.trim()

    if (query.length >= 3) {
      this.submitForm()
    } else {
      this.selectedIndex = -1
      this.frameTarget.innerHTML = this.originalHTML
    }
  }

  submitForm() {
    this.formTarget.requestSubmit()
  }

  resetSelection() {
    this.resetListSelection()
  }

  get resultItems() {
    return Array.from(this.frameTarget.querySelectorAll("[data-search-result]"))
  }
}
