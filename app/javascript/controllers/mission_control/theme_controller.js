import { Controller } from "@hotwired/stimulus"

const PREFERENCES = ["system", "light", "dark"]
const STORAGE_KEY = "mc-theme"

// Cycles system → light → dark, persists on this browser, paints html.dark.
export default class extends Controller {
  static targets = ["icon"]

  initialize() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.handleSystemChange = this.applyTheme.bind(this)
  }

  connect() {
    this.preference = this.#readPreference()
    document.documentElement.dataset.theme = this.preference
    this.mediaQuery.addEventListener("change", this.handleSystemChange)
    this.applyTheme()
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.handleSystemChange)
  }

  cycle(event) {
    event.preventDefault()
    const index = PREFERENCES.indexOf(this.preference)
    this.preference = PREFERENCES[(index + 1) % PREFERENCES.length]
    try {
      localStorage.setItem(STORAGE_KEY, this.preference)
    } catch {
      // Private mode or blocked storage — still apply for this page.
    }
    document.documentElement.dataset.theme = this.preference
    this.applyTheme()
  }

  applyTheme() {
    const systemIsDark = this.mediaQuery.matches
    const shouldBeDark = this.preference === "dark" || (this.preference !== "light" && systemIsDark)

    document.documentElement.classList.toggle("dark", shouldBeDark)
    this.#syncIcons()
  }

  #readPreference() {
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (PREFERENCES.includes(stored)) return stored
    } catch {
      // Ignore.
    }
    return document.documentElement.dataset.theme || "system"
  }

  #syncIcons() {
    for (const icon of this.iconTargets) {
      icon.hidden = icon.dataset.themeIcon !== this.preference
    }
  }
}
