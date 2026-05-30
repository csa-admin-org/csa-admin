import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.observers = []
    this.mutationObserver = null
    this.rescanScheduled = false

    this.setupActions()
    this.startMutationObserver()
  }

  disconnect() {
    this.stopMutationObserver()
    this.cleanupObservers()
  }

  setupActions() {
    this.element
      .querySelectorAll(".formtastic fieldset.actions")
      .forEach((fieldset) => this.observe(fieldset))
  }

  observe(fieldset) {
    // Defensive: remove any prior sentinel we may have left behind for this fieldset
    const next = fieldset.nextElementSibling
    if (next && next.dataset.stickySentinel === "true") {
      next.remove()
    }

    const sentinel = document.createElement("div")
    sentinel.setAttribute("aria-hidden", "true")
    sentinel.dataset.stickySentinel = "true"
    sentinel.style.height = "1px"
    sentinel.style.pointerEvents = "none"
    fieldset.after(sentinel)

    const observer = new IntersectionObserver(([entry]) => {
      fieldset.classList.toggle("is-stuck", !entry.isIntersecting)
    })
    observer.observe(sentinel)
    this.observers.push({ observer, sentinel })
  }

  cleanupObservers() {
    this.observers.forEach(({ observer, sentinel }) => {
      observer.disconnect()
      sentinel.remove()
    })
    this.observers = []
  }

  startMutationObserver() {
    this.mutationObserver = new MutationObserver(() => {
      this.scheduleRescan()
    })

    this.mutationObserver.observe(this.element, {
      childList: true,
      subtree: true
    })
  }

  stopMutationObserver() {
    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
      this.mutationObserver = null
    }
  }

  scheduleRescan() {
    if (this.rescanScheduled) return
    this.rescanScheduled = true

    requestAnimationFrame(() => {
      this.rescanScheduled = false
      this.cleanupObservers()
      this.setupActions()
    })
  }
}
