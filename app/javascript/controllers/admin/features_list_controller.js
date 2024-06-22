import { Controller } from "@hotwired/stimulus";
import { removeClass, addClass, prop } from "components/utils";

export default class extends Controller {
  toggleTab(event) {
    var feature = event.target.value;
    if (event.target.checked) {
      this.showTab(feature)
    } else {
      this.hideTab(feature)
    }
  }

  showTab(hash) {
    var tab = document.querySelector('[aria-controls="' + hash + '"]')
    if (tab) {
      removeClass(tab, "hidden")
      prop(this.allTabRequiredInputs(hash), "required", true)
      tab.click()
    }
  }

  hideTab(hash) {
    var tab = document.querySelector('[aria-controls="' + hash + '"]')
    if (tab) {
      addClass(tab, "hidden")
      prop(this.allTabRequiredInputs(hash), "required", false)
      this.showFirstActiveTab()
    }
  }

  showFirstActiveTab() {
    var activeFeatures = Array.from(
      this.element.querySelectorAll('input[type="checkbox"]:checked')
    ).map((feature) => { return feature.value })
    var firstActiveFeature = activeFeatures.find((feature) => {
      return document.querySelector('[aria-controls="' + feature + '"]') !== null
    })
    if (firstActiveFeature) {
      this.showTab(firstActiveFeature)
    }
  }

  allTabRequiredInputs(hash) {
    return Array.from(
      document.querySelectorAll('#' + hash + '[role="tabpanel"] li.required input')
    )
  }
}
