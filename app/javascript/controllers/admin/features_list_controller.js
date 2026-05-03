import { Controller } from "@hotwired/stimulus"
import { removeClass, addClass, prop } from "components/utils"

export default class extends Controller {
  connect() {
    for (const hash of this.allHiddenTabs()) {
      prop(this.allTabRequiredInputs(hash), "required", false)
    }
  }

  toggleTab(event) {
    const feature = event.target.value
    if (event.target.checked) {
      this.showTab(feature)
    } else {
      this.hideTab(feature)
    }
  }

  showTab(hash) {
    const tab = this.tabFor(hash)
    if (!tab) return

    if (hash !== "none") removeClass(tab, "hidden")
    prop(this.allTabRequiredInputs(hash), "required", true)
    tab.click()
  }

  hideTab(hash) {
    const tab = this.tabFor(hash)
    if (!tab) return

    addClass(tab, "hidden")
    prop(this.allTabRequiredInputs(hash), "required", false)
    this.showFirstActiveTab()
  }

  showFirstActiveTab() {
    const firstActiveFeature = this.activeFeatures().find((feature) => {
      return this.tabFor(feature) !== null
    })
    this.showTab(firstActiveFeature || "none")
  }

  activeFeatures() {
    return Array.from(
      this.element.querySelectorAll('input[type="checkbox"]:checked')
    ).map((feature) => feature.value)
  }

  allTabRequiredInputs(hash) {
    return Array.from(
      document.querySelectorAll(
        "#" + hash + '[role="tabpanel"] li.required input'
      )
    )
  }

  allHiddenTabs() {
    return this.tabs()
      .filter((tab) => tab.dataset.tabsHidden === "true")
      .map((tab) => tab.getAttribute("aria-controls"))
  }

  tabFor(hash) {
    return this.tabs().find((tab) => tab.getAttribute("aria-controls") === hash)
  }

  tabs() {
    return Array.from(document.querySelectorAll('#features [role="tab"]'))
  }
}
