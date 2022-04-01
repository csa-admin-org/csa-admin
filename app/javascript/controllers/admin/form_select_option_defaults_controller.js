import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  change(event) {
    let defaults = event.currentTarget.selectedOptions[0].dataset.formSelectOptionDefaults;
    if(defaults) {
      defaults = Object.entries(JSON.parse(defaults));
      defaults.forEach(([inputID, defaultValue]) => {
        const input = document.getElementById(inputID);
        input.value = defaultValue;
      })
    }
  }
}
