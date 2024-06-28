import { Controller } from "@hotwired/stimulus";
import { addClass, removeClass } from "components/utils";

export default class extends Controller {
  connect() {
    const hash = location.hash.substring(1)
    if (typeof hash === 'string' && hash.length > 0) {
      this.showTab(hash)
    }
    this._handleHiddenTabs()
  }

  showTab(hash) {
    const tab = this.element.querySelectorAll('[aria-controls="' + hash + '"]')[0]
    if (tab && tab.getAttribute("data-tabs-hidden") !== "true") {
      this._hideActiveTabs()
      tab.setAttribute("aria-selected", "true")
      const tabContent = document.getElementById(hash)
      removeClass(tabContent, "hidden")
      document.getElementById(hash).scrollIntoView();
    }
  }

  _hideActiveTabs() {
    const tabs = this.element.querySelectorAll("[aria-selected='true']")
    for (const tab of tabs) {
      tab.setAttribute("aria-selected", "false")
      const hash = tab.getAttribute("aria-controls")
      const tabContent = document.getElementById(hash)
      addClass(tabContent, "hidden")
    }
  }

  _handleHiddenTabs() {
    const tabs = this.element.querySelectorAll('a[data-tabs-hidden="true"]')
    for (const tab of tabs) {
      addClass(tab, "hidden")
    }
  }

  updateAnchor(event) {
    const hash = event.target.getAttribute("aria-controls")
    if (typeof hash === 'string' && hash.length > 0 && hash !== location.hash.substring(1)) {
      if (history.replaceState) {
        history.replaceState(null, null, `#${hash}`)
      } else {
        location.hash = hash
      }
    }
  }
}
