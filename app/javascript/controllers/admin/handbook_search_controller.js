import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"
import { listNavigation } from "admin/list_navigation"

// Manages the handbook sidebar search: submits a form to a Turbo Frame
// endpoint (debounced) when the query is long enough, and restores the
// original page list from a cached snapshot when the input is cleared.
//
// Supports keyboard navigation (up/down arrows + enter) over search
// results via the shared listNavigation mixin.
//
// Targets:
//   input – the text input field
//   frame – the <turbo-frame> wrapping the page list / results
//   form  – the search <form>
//
// Values:
//   currentPage – the handbook page currently being viewed (for context)
//
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
      // Restore cached page list immediately
      this.selectedIndex = -1
      this.frameTarget.innerHTML = this.originalHTML
    }
  }

  submitForm() {
    this.formTarget.requestSubmit()
  }

  // Called via turbo:frame-load on the frame target when new results arrive.
  // Auto-selects the first result so the user can immediately press enter.
  resetSelection() {
    this.resetListSelection()
  }

  get resultItems() {
    return Array.from(this.frameTarget.querySelectorAll("[data-search-result]"))
  }
}
