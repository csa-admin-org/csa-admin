import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static get targets() {
    return ["form"]
  }

  submit() {
    Turbo.navigator.submitForm(this.formTarget)
  }
}
