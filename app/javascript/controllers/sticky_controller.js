import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    offset: Number,
    desktopOffset: Number
  }
  static classes = ["sticky"]

  connect() {
    var offset = (window.innerWidth <= 768) ? this.offsetValue : this.desktopOffsetValue
    this.application.offset = this.containerTarget.offsetTop + offset
  }

  update() {
    if (window.pageYOffset >= this.application.offset) {
      this.containerTarget.classList.add(...this.stickyClasses)
    } else {
      this.containerTarget.classList.remove(...this.stickyClasses)
    }
  }
}
