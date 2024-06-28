import { Controller } from "@hotwired/stimulus";
import { prop, addClass } from "components/utils";

export default class extends Controller {
  connect() {
    const hash = location.hash.substring(1)
    if (typeof hash === 'string' && hash.length > 0) {
      this.showTab(hash)
    }
    this.hideTabs()
  }

  showTab(hash) {
    const tab = this.element.querySelectorAll('[aria-controls="' + hash + '"]')[0]
    if (tab && tab.getAttribute("data-tabs-hidden") != "true") {
      prop("[aria-selected='true']", "aria-selected", false)
      tab.setAttribute("aria-selected", "true")
      document.getElementById(hash).scrollIntoView();
    }
  }

  hideTabs() {
    const tabs = this.element.querySelectorAll('a[data-tabs-hidden="true"]')
    for (const tab of tabs) {
      addClass(tab, "hidden")
    }
  }

  updateAnchor(event) {
    const hash = event.target.getAttribute("aria-controls")
    if (typeof hash !== 'string' || hash.length === 0) {
      return
    }

    if (hash !== location.hash.substring(1)) {
      if (history.replaceState) {
        history.replaceState(null, null, `#${hash}`)
      } else {
        location.hash = hash
      }
    }
  }
}
