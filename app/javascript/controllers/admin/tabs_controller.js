import { Controller } from "@hotwired/stimulus"
import { addClass, removeClass } from "components/utils"

export default class extends Controller {
  connect() {
    const hash = location.hash.substring(1)
    this._handleHiddenTabs()
    if (hash && this.showTab(hash)) {
      document.getElementById(hash)?.scrollIntoView()
    } else {
      this._showDefaultTab()
    }
  }

  switchTab(event) {
    event.preventDefault()
    const hash = event.currentTarget.getAttribute("aria-controls")
    if (hash && this.showTab(hash)) {
      this._updateAnchor(hash)
    }
  }

  showTab(hash) {
    const tab = this._tabFor(hash)
    const tabContent = document.getElementById(hash)
    if (!tab || !tabContent || !this._canShowTab(tab)) return false

    this._hideActiveTabs()
    tab.setAttribute("aria-selected", "true")
    removeClass(tabContent, "hidden")
    return true
  }

  _hideActiveTabs() {
    for (const tab of this._selectedTabs()) {
      tab.setAttribute("aria-selected", "false")
      addClass(
        document.getElementById(tab.getAttribute("aria-controls")),
        "hidden"
      )
    }
  }

  _handleHiddenTabs() {
    for (const tab of this._tabs().filter(
      (tab) => tab.dataset.tabsHidden === "true"
    )) {
      addClass(tab, "hidden")
    }
  }

  _showDefaultTab() {
    const tab =
      this._selectedVisibleTab() ||
      this._firstVisibleTab() ||
      this._selectedTabs()[0]
    if (tab) this.showTab(tab.getAttribute("aria-controls"))
  }

  _tabs() {
    const tablist = this.element.querySelector(":scope > .tabs-nav")
    return Array.from(tablist?.querySelectorAll('[role="tab"]') || [])
  }

  _selectedTabs() {
    return this._tabs().filter(
      (tab) => tab.getAttribute("aria-selected") === "true"
    )
  }

  _selectedVisibleTab() {
    return this._selectedTabs().find((tab) => this._isVisibleTab(tab))
  }

  _firstVisibleTab() {
    return this._tabs().find((tab) => this._isVisibleTab(tab))
  }

  _tabFor(hash) {
    return this._tabs().find(
      (tab) => tab.getAttribute("aria-controls") === hash
    )
  }

  _isVisibleTab(tab) {
    return !tab.classList.contains("hidden")
  }

  _canShowTab(tab) {
    return (
      this._isVisibleTab(tab) || tab.getAttribute("aria-controls") === "none"
    )
  }

  _updateAnchor(hash) {
    if (hash && hash !== location.hash.substring(1)) {
      history.replaceState(null, null, `#${hash}`)
    }
  }
}
