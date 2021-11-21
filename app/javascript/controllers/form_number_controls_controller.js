import { Controller } from "@hotwired/stimulus"
import debounce  from 'lodash/debounce'

export default class extends Controller {
  static targets = ["input"]

  initialize() {
    this.inputChanged = debounce(this.inputChanged, 250).bind(this)
  }

  increment(event) {
    var i = this.inputTarget.value;
    if (!this.inputTarget.max || i < this.inputTarget.max) {
      this.inputTarget.value = ++i;
      this.inputChanged()
    }
    event.preventDefault()
  }

  decrement(event) {
    var i = this.inputTarget.value;
    if (i > this.inputTarget.min) {
      this.inputTarget.value = --i;
      this.inputChanged()
    }
    event.preventDefault()
  }

  inputChanged() {
    var event = new Event('change', {
      bubbles: true,
      cancelable: true,
    });
    console.log('changed!')
    this.inputTarget.dispatchEvent(event);
  }
}
