import { Controller } from "@hotwired/stimulus"

// Turns a static HTML structure into a custom select-like dropdown that
// displays an icon + label for each option.  Used for the theme picker
// in both admin and member account forms.
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

    // Swap the displayed icon by cloning the one from the selected option
    const newIcon = option.querySelector("svg")
    if (newIcon) {
      this.iconSlotTarget.innerHTML = ""
      this.iconSlotTarget.appendChild(newIcon.cloneNode(true))
    }

    // Update selected highlight
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
