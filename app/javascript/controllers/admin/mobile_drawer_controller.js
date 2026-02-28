import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "content"]
  static values = { sourceSelector: String }

  connect() {
    if (this.hasSourceSelectorValue) {
      this.sourceElement = document.querySelector(this.sourceSelectorValue)
      this.mediaQuery = window.matchMedia("(max-width: 1023px)")
      this.handleMediaChange = this.handleMediaChange.bind(this)
      this.mediaQuery.addEventListener("change", this.handleMediaChange)
      this.handleMediaChange()
    }
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener("change", this.handleMediaChange)
    }
    this.restoreContent()
  }

  handleMediaChange() {
    if (this.mediaQuery.matches) {
      this.moveContent()
    } else {
      this.restoreContent()
    }
  }

  moveContent() {
    if (!this.sourceElement || !this.hasContentTarget) return
    if (this.contentTarget.children.length > 0) return

    this.contentTarget.append(...this.sourceElement.children)
    this.sourceElement
      .closest("[id$='_sidebar_section']")
      ?.classList.add("hidden")
  }

  restoreContent() {
    if (!this.sourceElement || !this.hasContentTarget) return
    if (this.contentTarget.children.length === 0) return

    this.sourceElement.append(...this.contentTarget.children)
    this.sourceElement
      .closest("[id$='_sidebar_section']")
      ?.classList.remove("hidden")
  }

  open() {
    this.overlayTarget.classList.remove("hidden")
    // Force reflow before adding transition classes
    this.overlayTarget.offsetHeight
    this.overlayTarget.classList.add("open")
    this.panelTarget.classList.add("open")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.overlayTarget.classList.remove("open")
    this.panelTarget.classList.remove("open")

    const handler = () => {
      this.overlayTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
      this.overlayTarget.removeEventListener("transitionend", handler)
    }
    this.overlayTarget.addEventListener("transitionend", handler)

    // Fallback in case transitionend doesn't fire
    setTimeout(() => {
      if (!this.overlayTarget.classList.contains("open")) {
        this.overlayTarget.classList.add("hidden")
        document.body.classList.remove("overflow-hidden")
      }
    }, 300)
  }

  closeOnOutside(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  navigate() {
    this.close()
  }
}
