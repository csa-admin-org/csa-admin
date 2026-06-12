import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["token", "tooltipTemplate"]
  static values = {
    apiEndpoint: String,
    wasmUrl: String,
    verifyingMessage: String,
    failedMessage: String,
    unavailableMessage: String
  }

  connect() {
    this.form = this.element.closest("form")
    this.submitButtons = this.form
      ? Array.from(this.form.querySelectorAll("button[type='submit'], input[type='submit']"))
      : []
    this.handleSubmit = this.submit.bind(this)
    this.form?.addEventListener("submit", this.handleSubmit)

    this.solve()
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.handleSubmit)
    this.cap?.reset()
    this.cap?.widget?.remove()
    this.removeSubmitTooltip()
  }

  async submit(event) {
    if (this.tokenTarget.value) return

    event.preventDefault()
    await this.solve()

    if (this.tokenTarget.value) {
      this.form.requestSubmit(event.submitter)
    }
  }

  async solve() {
    if (this.solving || this.tokenTarget.value) return
    if (!this.apiEndpointValue) return this.unavailable()

    this.solving = true
    this.disableSubmit()
    this.showStatus(this.verifyingMessageValue)
    this.configureCapGlobals()

    try {
      await this.loadCap()
      this.cap ||= new window.Cap({ apiEndpoint: this.apiEndpointValue })
      const result = await this.cap.solve()

      if (result?.success && result.token) {
        this.tokenTarget.value = result.token
        this.removeSubmitTooltip()
        this.enableSubmit()
      } else {
        this.failed()
      }
    } catch (error) {
      console.warn("Cap verification failed", error)
      this.failed()
    } finally {
      this.solving = false
    }
  }

  async loadCap() {
    if (!window.Cap) await import("cap-widget")
  }

  configureCapGlobals() {
    if (this.wasmUrlValue) {
      window.CAP_CUSTOM_WASM_URL = this.wasmUrlValue
    }

    const nonce = document.querySelector("meta[name='csp-nonce']")?.content
    if (nonce) {
      window.CAP_SCRIPT_NONCE = nonce
      window.CAP_CSS_NONCE = nonce
    }
  }

  unavailable() {
    this.disableSubmit()
    this.showStatus(this.unavailableMessageValue, "error")
  }

  failed() {
    this.disableSubmit()
    this.showStatus(this.failedMessageValue)
  }

  showStatus(message) {
    const tooltip = this.ensureSubmitTooltip()
    if (!tooltip) return

    tooltip.querySelector("p").textContent = message
  }

  ensureSubmitTooltip() {
    const wrapper = this.submitWrapper()
    if (!wrapper || !this.hasTooltipTemplateTarget) return null

    if (!this.tooltipContent) {
      this.tooltipContent = this.tooltipTemplateTarget.content.firstElementChild.cloneNode(true)
      this.tooltipContent.id ||= `cap-tooltip-${Date.now()}-${Math.random().toString(36).slice(2)}`
      wrapper.append(this.tooltipContent)
    }

    wrapper.tabIndex = 0
    wrapper.classList.add("cursor-not-allowed")
    wrapper.setAttribute("aria-describedby", this.tooltipContent.id)
    this.submitButtons.forEach((button) => (button.style.pointerEvents = "none"))
    this.addSubmitTooltipListeners(wrapper)

    return this.tooltipContent
  }

  removeSubmitTooltip() {
    const wrapper = this.submitWrapper()
    if (!wrapper) {
      this.tooltipContent?.remove()
      this.tooltipContent = null
      return
    }

    this.removeSubmitTooltipListeners(wrapper)
    this.submitTooltipController()?.hide()
    wrapper.removeAttribute("aria-describedby")
    wrapper.removeAttribute("tabindex")
    wrapper.classList.remove("cursor-not-allowed")
    this.submitButtons.forEach((button) => (button.style.pointerEvents = ""))

    this.tooltipContent?.remove()
    this.tooltipContent = null
  }

  submitWrapper() {
    return this.submitButtons[0]?.closest(".actions") || this.submitButtons[0]?.parentElement
  }

  addSubmitTooltipListeners(wrapper) {
    if (this.submitTooltipListeners) return

    this.submitTooltipListeners = {
      show: () => this.submitTooltipController()?.show(),
      hide: () => this.submitTooltipController()?.hide(),
      showForTouch: (event) => {
        if (event.pointerType && event.pointerType === "mouse") return

        this.submitTooltipController()?.show()
      }
    }

    wrapper.addEventListener("mouseenter", this.submitTooltipListeners.show)
    wrapper.addEventListener("mouseleave", this.submitTooltipListeners.hide)
    wrapper.addEventListener("focus", this.submitTooltipListeners.show)
    wrapper.addEventListener("blur", this.submitTooltipListeners.hide)
    wrapper.addEventListener("pointerdown", this.submitTooltipListeners.showForTouch)
    wrapper.addEventListener("touchstart", this.submitTooltipListeners.showForTouch, {
      passive: true
    })
    wrapper.addEventListener("click", this.submitTooltipListeners.show)
  }

  removeSubmitTooltipListeners(wrapper) {
    if (!this.submitTooltipListeners) return

    wrapper.removeEventListener("mouseenter", this.submitTooltipListeners.show)
    wrapper.removeEventListener("mouseleave", this.submitTooltipListeners.hide)
    wrapper.removeEventListener("focus", this.submitTooltipListeners.show)
    wrapper.removeEventListener("blur", this.submitTooltipListeners.hide)
    wrapper.removeEventListener("pointerdown", this.submitTooltipListeners.showForTouch)
    wrapper.removeEventListener("touchstart", this.submitTooltipListeners.showForTouch)
    wrapper.removeEventListener("click", this.submitTooltipListeners.show)
    this.submitTooltipListeners = null
  }

  submitTooltipController() {
    const wrapper = this.submitWrapper()
    if (!wrapper) return null

    return this.application.getControllerForElementAndIdentifier(wrapper, "tooltip")
  }

  disableSubmit() {
    this.submitButtons.forEach((button) => (button.disabled = true))
  }

  enableSubmit() {
    this.submitButtons.forEach((button) => (button.disabled = false))
  }
}
