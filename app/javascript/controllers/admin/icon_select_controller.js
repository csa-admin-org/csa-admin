import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "iconSlot", "dropdown", "input"]
  static values = { open: { type: Boolean, default: false } }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  select(event) {
    const option = event.currentTarget
    const value = option.dataset.value
    const label = option.dataset.label

    this.inputTarget.value = value
    this.labelTarget.textContent = label

    const newIcon = option.querySelector("svg")
    if (newIcon) {
      this.iconSlotTarget.innerHTML = ""
      this.iconSlotTarget.appendChild(newIcon.cloneNode(true))
    }

    this.dropdownTarget.querySelectorAll("li").forEach((li) => {
      li.classList.toggle("bg-gray-100", li.dataset.value === value)
      li.classList.toggle("dark:bg-gray-700", li.dataset.value === value)
    })

    this.close()
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    this.dropdownTarget.classList.toggle("hidden", !this.openValue)
  }
}
