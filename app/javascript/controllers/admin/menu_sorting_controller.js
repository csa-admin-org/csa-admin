import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const menu = this.element.nextElementSibling;
    Array.from(menu.getElementsByTagName('li'))
      .sort((a, b) => a.textContent.localeCompare(b.textContent))
      .forEach(li => menu.appendChild(li));
  }
}
