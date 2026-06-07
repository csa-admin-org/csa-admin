import { Controller } from "@hotwired/stimulus"

const highlightClass = "animate-settings-anchor-highlight"

export default class extends Controller {
  connect() {
    this.pulseCurrentAnchor = this.pulseCurrentAnchor.bind(this)
    this.clearHighlight = this.clearHighlight.bind(this)

    requestAnimationFrame(this.pulseCurrentAnchor)
    window.addEventListener("hashchange", this.pulseCurrentAnchor)
    document.addEventListener("turbo:before-cache", this.clearHighlight)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.pulseCurrentAnchor)
    document.removeEventListener("turbo:before-cache", this.clearHighlight)
    this.clearHighlight()
  }

  pulseCurrentAnchor() {
    const hash = this.currentHash()
    if (!hash) {
      this.clearHighlight()
      return
    }

    const anchor = document.getElementById(hash)
    if (!anchor || !this.element.contains(anchor)) return

    const target = this.highlightTargetFor(anchor)
    if (!target) return

    this.pulseElement(this.highlightElementFor(target))
  }

  currentHash() {
    const hash = window.location.hash?.slice(1)
    if (!hash) return

    try {
      return decodeURIComponent(hash)
    } catch {
      return hash
    }
  }

  highlightTargetFor(anchor) {
    if (anchor.hasAttribute("data-settings-anchor-highlight-target")) {
      return anchor
    }

    const target = anchor.closest("[data-settings-anchor-highlight-target]")
    if (target && this.element.contains(target)) return target
  }

  highlightElementFor(target) {
    return Array.from(target.children).find((child) => child.classList.contains("panel")) || target
  }

  pulseElement(element) {
    this.clearHighlight()

    this.highlightedElement = element
    this.removeHighlight = () => this.clearHighlight()

    element.classList.remove(highlightClass)
    void element.offsetWidth
    element.classList.add(highlightClass)
    element.addEventListener("animationend", this.removeHighlight, { once: true })
  }

  clearHighlight() {
    if (!this.highlightedElement) return

    if (this.removeHighlight) {
      this.highlightedElement.removeEventListener("animationend", this.removeHighlight)
    }

    this.highlightedElement.classList.remove(highlightClass)
    this.highlightedElement = null
    this.removeHighlight = null
  }
}
