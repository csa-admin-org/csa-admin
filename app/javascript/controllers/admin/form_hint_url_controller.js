import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["link"]
  }

  change(event) {
    let data = event.currentTarget.selectedOptions[0].dataset.formHintUrl;
    if(data) {
      data = JSON.parse(data);
      this.linkTarget.href = data.href;
      this.linkTarget.textContent = data.text;
    } else {
      this.linkTarget.textContent = '';
    }
  }
}
