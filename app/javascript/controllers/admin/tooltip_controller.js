import { Controller } from "@hotwired/stimulus"
import { arrow, autoUpdate, computePosition, flip, offset, shift } from "@floating-ui/dom"

// Positions hover tooltips and click-triggered dropdowns/popovers with Floating UI.
let openDismissibleTooltip = null

export default class extends Controller {
  static targets = ["trigger", "content", "arrow"]
  static values = {
    dismissible: { type: Boolean, default: false },
    placement: { type: String, default: "top" }
  }

  connect() {
    this._handleDocumentClick = this._handleDocumentClick.bind(this)
    this._handleEscape = this._handleEscape.bind(this)
  }

  disconnect() {
    this._close()
  }

  show() {
    this._show()
  }

  hide() {
    this._close()
  }

  preview() {
    this.cancelHidePreview()
    if (this._pinned) return

    this._previewing = true
    this._show()
  }

  hidePreview(event) {
    if (!this._previewing || this._pinned) return
    if (this._movingWithinTooltip(event)) return

    this._schedulePreviewHide()
  }

  cancelHidePreview() {
    if (this._previewHideTimeout) {
      clearTimeout(this._previewHideTimeout)
      this._previewHideTimeout = null
    }
  }

  toggle() {
    this.cancelHidePreview()

    if (this._pinned) {
      this.hide()
    } else {
      this._previewing = false
      this._pinned = true
      this._show()
    }
  }

  _show() {
    if (this.dismissibleValue) {
      this._closeOpenDismissibleTooltip()
      openDismissibleTooltip = this
    }

    const request = this._newShowRequest()
    this._position().then((trigger) => {
      if (!trigger || !this._isCurrentShowRequest(request)) return

      this._showContent()
      this._startAutoUpdate(trigger)
      this._addDismissListeners()
    })
  }

  _close() {
    this._newShowRequest()
    this.cancelHidePreview()
    this._previewing = false
    this._pinned = false
    this._hideContent()
    this._stopAutoUpdate()
    this._removeDismissListeners()
  }

  _showContent() {
    if (!this.hasContentTarget) return

    this.contentTarget.classList.remove("invisible", "opacity-0")
    this.contentTarget.classList.add("visible", "opacity-100")
    this._syncExpandedState(true)
  }

  _hideContent() {
    if (!this.hasContentTarget) return

    this.contentTarget.classList.add("invisible", "opacity-0")
    this.contentTarget.classList.remove("visible", "opacity-100")
    this._syncExpandedState(false)
  }

  _isHidden() {
    return !this.hasContentTarget || this.contentTarget.classList.contains("invisible")
  }

  _closeOpenDismissibleTooltip() {
    if (openDismissibleTooltip && openDismissibleTooltip !== this) {
      openDismissibleTooltip.hide()
    }
  }

  _schedulePreviewHide() {
    this.cancelHidePreview()

    this._previewHideTimeout = setTimeout(() => {
      if (!this._previewing || this._pinned) return

      this.hide()
    }, 150)
  }

  _movingWithinTooltip(event) {
    return event?.relatedTarget instanceof Node && this.element.contains(event.relatedTarget)
  }

  _addDismissListeners() {
    if (!this.dismissibleValue) return

    requestAnimationFrame(() => {
      if (openDismissibleTooltip !== this || this._isHidden()) return

      document.addEventListener("click", this._handleDocumentClick)
      document.addEventListener("keydown", this._handleEscape)
    })
  }

  _removeDismissListeners() {
    if (openDismissibleTooltip === this) openDismissibleTooltip = null

    document.removeEventListener("click", this._handleDocumentClick)
    document.removeEventListener("keydown", this._handleEscape)
  }

  _handleDocumentClick(event) {
    if (!this.element.contains(event.target)) this.hide()
  }

  _handleEscape(event) {
    if (event.key === "Escape") this.hide()
  }

  _startAutoUpdate(trigger) {
    if (!this.hasContentTarget) return

    this._stopAutoUpdate()
    this._cleanupAutoUpdate = autoUpdate(trigger, this.contentTarget, () => {
      this._position()
    })
  }

  _stopAutoUpdate() {
    if (this._cleanupAutoUpdate) {
      this._cleanupAutoUpdate()
      this._cleanupAutoUpdate = null
    }
  }

  _newShowRequest() {
    this._showRequest = (this._showRequest || 0) + 1
    return this._showRequest
  }

  _isCurrentShowRequest(request) {
    return (
      this._showRequest === request && (!this.dismissibleValue || openDismissibleTooltip === this)
    )
  }

  async _position() {
    const trigger = this._triggerTarget()
    if (!trigger || !this.hasContentTarget) return null

    const content = this.contentTarget
    const arrowEl = this.hasArrowTarget ? this.arrowTarget : null

    Object.assign(content.style, {
      position: "fixed",
      left: "0px",
      top: "0px"
    })

    const middleware = [offset(8), flip(), shift({ padding: 3 })]
    if (arrowEl) middleware.push(arrow({ element: arrowEl }))

    const { x, y, placement, middlewareData } = await computePosition(trigger, content, {
      placement: this.placementValue,
      strategy: "fixed",
      middleware
    })

    Object.assign(content.style, {
      left: `${x}px`,
      top: `${y}px`
    })

    if (arrowEl && middlewareData.arrow) {
      this._positionArrow(arrowEl, placement, middlewareData.arrow)
    }

    return trigger
  }

  _positionArrow(arrowEl, placement, { x, y }) {
    const staticSide = {
      top: "bottom",
      right: "left",
      bottom: "top",
      left: "right"
    }[placement.split("-")[0]]

    Object.assign(arrowEl.style, {
      left: x != null ? `${x}px` : "",
      top: y != null ? `${y}px` : "",
      right: "",
      bottom: "",
      [staticSide]: "-4px"
    })
  }

  _syncExpandedState(expanded) {
    if (!this.dismissibleValue || !this.hasTriggerTarget) return

    this.triggerTarget.setAttribute("aria-expanded", expanded)
  }

  _triggerTarget() {
    return this.hasTriggerTarget ? this.triggerTarget : this.element
  }
}
