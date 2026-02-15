import { Controller } from "@hotwired/stimulus"

// Applies the admin's theme preference set via a Stimulus value on <body>
// (server-rendered from the admin's persisted setting).
//
// Supported values: "light", "dark", "system" (default).
//
// In "system" mode the controller listens for OS-level theme changes and
// toggles the `dark` class on <html> accordingly.
//
// The preference is passed as a Stimulus value on <body> so that it is
// automatically picked up on Turbo visits (body replacement) and morph
// refreshes (value change callback).
//
// Some browsers (notably Safari) don't reliably fire the matchMedia `change`
// event when toggling the appearance from the Web Inspector. A lightweight
// polling fallback detects those missed changes.
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
