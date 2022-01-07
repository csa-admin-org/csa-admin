import { Controller } from "@hotwired/stimulus"
import { debounce } from 'throttle-debounce'

export default class extends Controller {
  static get targets() {
    return ["input"]
  }

  initialize() {
    this.inputChanged = debounce(250, this.inputChanged)
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
    var event = new Event('change', {
      bubbles: true,
      cancelable: true,
    });
    this.inputTarget.dispatchEvent(event);
  }
}
