import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { preference: { type: String, default: "system" } }

  initialize() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.handleSystemChange = this.applyTheme.bind(this)
    this.handleVisibilityChange = this.applyTheme.bind(this)
  }

  connect() {
    this.mediaQuery.addEventListener("change", this.handleSystemChange)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
    window.addEventListener("focus", this.handleVisibilityChange)

    // Poll matchMedia.matches so that Web Inspector appearance toggles
    // are picked up even when the `change` event doesn't fire.
    this.lastMatches = this.mediaQuery.matches
    this.pollId = setInterval(() => {
      if (this.mediaQuery.matches !== this.lastMatches) {
        this.lastMatches = this.mediaQuery.matches
        this.applyTheme()
      }
    }, 300)

    this.applyTheme()
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.handleSystemChange)
    document.removeEventListener(
      "visibilitychange",
      this.handleVisibilityChange
    )
    window.removeEventListener("focus", this.handleVisibilityChange)
    clearInterval(this.pollId)
  }

  preferenceValueChanged() {
    this.applyTheme()
  }

  applyTheme() {
    const preference = this.preferenceValue
    const systemIsDark = this.mediaQuery.matches
    const shouldBeDark =
      preference === "dark" || (preference !== "light" && systemIsDark)

    this.lastMatches = systemIsDark

    document.documentElement.classList.toggle("dark", shouldBeDark)
  }
}
