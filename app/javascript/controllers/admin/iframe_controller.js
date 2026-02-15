import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["iframe"]
  }

  iframeTargetConnected(element) {
    // srcdoc iframes often load before Stimulus connects the target,
    // especially during Turbo visits. Try immediately, and also set
    // onload as a fallback for slower loads.
    element.onload = () => {
      this._resize()
      this._setColorScheme()
    }
    this._applyWhenReady(element)
  }

  _applyWhenReady(element, attempts = 0) {
    const body = this._iframeBody(element)
    if (body) {
      this._resize()
      this._setColorScheme()
    } else if (attempts < 10) {
      setTimeout(() => this._applyWhenReady(element, attempts + 1), 50)
    }
  }

  _resize() {
    const heights = this._iframeBodies().map((body) => body.offsetHeight)
    this.iframeTargets.forEach(
      (i) => (i.style.height = Math.max(...heights) + "px")
    )
  }

  _setColorScheme() {
    const dark = document.documentElement.classList.contains("dark")
    this._iframeBodies().forEach((body) => {
      body.classList.toggle("dark", dark)
    })
  }

  _iframeBody(element) {
    try {
      return element.contentWindow.document.body
    } catch (e) {
      return null
    }
  }

  _iframeBodies() {
    return this.iframeTargets.map((i) => this._iframeBody(i)).filter(Boolean)
  }
}
