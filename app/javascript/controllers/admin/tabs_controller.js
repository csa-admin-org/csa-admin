import { Controller } from "@hotwired/stimulus";
import { addClass } from "components/utils";

export default class extends Controller {
  connect() {
    var hash = location.hash.substring(1)
    if (hash) {
      this.showTab(hash)
    }
    this.hideTabs()
  }

  showTab(hash) {
    var tab = this.element.querySelectorAll('[aria-controls="' + hash + '"]')[0]
    if (tab && tab.getAttribute("data-tabs-hidden") != "true") {
      tab.click()
      document.getElementById(hash).scrollIntoView();
    }
  }

  hideTabs() {
    var tabs = this.element.querySelectorAll('a[data-tabs-hidden="true"]')
    for (const tab of tabs) {
      addClass(tab, "hidden")
    }
  }

  updateAnchor(event) {
    var hash = event.target.getAttribute("aria-controls")
    if (hash && hash != location.hash.substring(1)) {
      if (history.replaceState) {
        history.replaceState(null, null, "#" + hash)
      }
      else {
        location.hash = hash
      }
    }
  }
}
