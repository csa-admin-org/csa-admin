import { Controller } from "@hotwired/stimulus"
import debounce  from 'lodash/debounce'

export default class extends Controller {
  static targets = ["input"]

  initialize() {
    this.inputChanged = debounce(this.inputChanged, 250).bind(this)
  }

  increment(event) {
    var i = parseInt(this.inputTarget.value)
    var max = parseInt(this.inputTarget.max)
    if (!max || i < max) {
      this.inputTarget.value = ++i;
      this.inputChanged()
    }
    event.preventDefault()
  }

  decrement(event) {
    var i = parseInt(this.inputTarget.value)
    var min = parseInt(this.inputTarget.min)
    if (i > min) {
      this.inputTarget.value = --i;
      this.inputChanged()
    }
    event.preventDefault()
  }

  inputChanged() {
    console.log('changed')
    var event = new Event('change', {
      bubbles: true,
      cancelable: true,
    });
    this.inputTarget.dispatchEvent(event);
  }
}
