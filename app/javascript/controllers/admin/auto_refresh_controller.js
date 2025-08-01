import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 2000 }
  }

  connect() {
    this.refresh()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  refresh() {
    this.timeout = setTimeout(() => Turbo.visit(location.href), this.delayValue)
  }
}
