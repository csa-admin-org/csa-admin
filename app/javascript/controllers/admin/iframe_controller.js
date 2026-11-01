import { Controller } from "@hotwired/stimulus"

const HEIGHT_MESSAGE = "csa-admin:mail-preview-height"
const MEASURE_MESSAGE = "csa-admin:mail-preview-measure"
const MAX_HEIGHT = 8000

export default class extends Controller {
  static get targets() {
    return ["iframe"]
  }

  connect() {
    window.addEventListener("message", this._onMessage)
  }

  disconnect() {
    window.removeEventListener("message", this._onMessage)
    this.iframeTargets.forEach((iframe) => {
      iframe.removeEventListener("load", this._onIframeLoad)
    })
  }

  iframeTargetConnected(element) {
    element.addEventListener("load", this._onIframeLoad)
    this._requestHeight(element)
  }

  iframeTargetDisconnected(element) {
    element.removeEventListener("load", this._onIframeLoad)
  }

  // Bound at construction. Stimulus connects targets before connect(),
  // and a loaded srcdoc iframe fires load in that window.
  _onIframeLoad = (event) => {
    this._requestHeight(event.currentTarget)
  }

  _requestHeight(iframe) {
    iframe.contentWindow?.postMessage({ type: MEASURE_MESSAGE }, "*")
  }

  _onMessage = (event) => {
    const data = event.data
    if (!data || data.type !== HEIGHT_MESSAGE) return

    const height = Math.min(Math.ceil(Number(data.height)), MAX_HEIGHT)
    if (!Number.isFinite(height) || height <= 0) return

    this.iframeTargets.forEach((iframe) => {
      if (iframe.contentWindow === event.source) {
        iframe.style.height = `${height}px`
      }
    })
  }
}
