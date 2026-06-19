import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"
import { listNavigation } from "admin/list_navigation"

export default class extends Controller {
  static targets = ["dialog", "input", "results", "hint", "form"]
  static values = { initialQuery: String }

  initialize() {
    this.submitForm = debounce(200, this.submitForm)
    this.handleResultsMouseMove = this.handleResultsMouseMove.bind(this)
  }

  connect() {
    const nav = listNavigation()
    this._highlightItem = nav._highlightItem
    this._clearHighlight = nav._clearHighlight
    this.resetListSelection = nav.resetListSelection

    this.selectedIndex = -1
    this.showHint = false
    this.keyboardMode = false

    if (window.matchMedia("(pointer: fine)").matches) {
      const platform = this.isMac ? "mac" : "other"
      this.hintTarget.querySelector(`[data-platform="${platform}"]`)?.classList.remove("hidden")
    }

    this.resultsTarget.addEventListener("mousemove", this.handleResultsMouseMove)

    if (this.initialQueryValue) {
      requestAnimationFrame(() => {
        this.inputTarget.value = this.initialQueryValue
        this.open({ viaShortcut: true })
        // Place cursor at end of input so the user can continue typing
        const len = this.inputTarget.value.length
        this.inputTarget.setSelectionRange(len, len)
        this.search()

        // Clean up the URL param without a page reload
        const url = new URL(window.location)
        url.searchParams.delete("search")
        history.replaceState(history.state, "", url)
      })
    }
  }

  disconnect() {
    this.resultsTarget.removeEventListener("mousemove", this.handleResultsMouseMove)
    if (this.isOpen) this.unlockPage()
  }

  openViaShortcut() {
    this.open({ viaShortcut: true })
  }

  openViaClick(event) {
    event.preventDefault()
    this.open({ viaShortcut: false })
  }

  open({ viaShortcut = false } = {}) {
    if (!this.isOpen) {
      this.dialogTarget.showModal()
    }

    this.lockPage()
    this.inputTarget.focus()
    this.inputTarget.select()

    this.showHint = !viaShortcut
    this.toggleHint(this.showHint)
  }

  close(event) {
    if (!this.isOpen) return

    event?.preventDefault()
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target !== this.dialogTarget) return

    this.close(event)
  }

  closed() {
    this.selectedIndex = -1
    this.setKeyboardMode(false, this.resultItems)
    this.unlockPage()
    this.toggleHint(false)
  }

  search() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2 || (query.length < 3 && !/^\d+$/.test(query))) {
      this.resultsTarget.innerHTML = ""
      this.selectedIndex = -1
      this.setKeyboardMode(false, this.resultItems)
      this.toggleHint(this.showHint)
      return
    }

    this.toggleHint(false)

    this.submitForm()
  }

  submitForm() {
    this.formTarget.requestSubmit()
  }

  resetSelection() {
    if (!this.isOpen) return

    this.resetListSelection()
  }

  navigateDown(event) {
    if (!this.isOpen) return

    event.preventDefault()
    const items = this.resultItems
    if (items.length === 0) return

    this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
    this._highlightItem(items)
    this.setKeyboardMode(true, items)
  }

  navigateUp(event) {
    if (!this.isOpen) return

    event.preventDefault()
    const items = this.resultItems
    if (items.length === 0) return

    if (this.selectedIndex <= 0) {
      this.selectedIndex = -1
      this._clearHighlight(items)
      this.setKeyboardMode(true, items)
      this.inputTarget.focus()
      return
    }

    this.selectedIndex = this.selectedIndex - 1
    this._highlightItem(items)
    this.setKeyboardMode(true, items)
  }

  selectCurrent(event) {
    if (!this.isOpen || event.isComposing) return

    event.preventDefault()
    const items = this.resultItems
    const index = this.selectedIndex
    if (index >= 0 && index < items.length) {
      this.close()
      items[index].click()
    }
  }

  selectItem() {
    // Let the link navigate naturally, just close the modal
    this.close()
  }

  setKeyboardMode(active, items = this.resultItems) {
    this.keyboardMode = active
    items.forEach((item, index) => {
      if (!active) {
        item.style.backgroundColor = ""
        return
      }
      if (index === this.selectedIndex) {
        item.style.backgroundColor = ""
        return
      }
      item.style.backgroundColor = "transparent"
    })
  }

  handleResultsMouseMove(event) {
    if (!this.isOpen) return

    const hoveredItem = event.target.closest("[data-search-result]")
    const items = this.resultItems
    const hoveredIndex = hoveredItem ? items.indexOf(hoveredItem) : -1

    this.selectedIndex = hoveredIndex
    this._clearHighlight(items)
    if (this.keyboardMode) {
      this.setKeyboardMode(false, items)
    }
  }

  lockPage() {
    document.body.classList.add("overflow-hidden")
  }

  unlockPage() {
    document.body.classList.remove("overflow-hidden")
  }

  toggleHint(visible) {
    this.hintTarget.classList.toggle("hidden", !visible)
  }

  get resultItems() {
    return Array.from(this.resultsTarget.querySelectorAll("[data-search-result]"))
  }

  get isOpen() {
    return this.dialogTarget.open
  }

  get isMac() {
    return /Mac|iPhone|iPod|iPad/i.test(navigator.platform || navigator.userAgent)
  }
}
