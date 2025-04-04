import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._hightlightActiveFilters()
    this._disableFormClearLinkWhenNoActiveFilters()
  }

  submit(event) {
    const form = event.target.closest("form")
    if (!form) return

    if (this.isSelectSearch(event.target)) {
      if (event.target.nextElementSibling.value != "") {
        // Let the select_and_search active admin JS do its job first
        setTimeout(() => {
          form.submit()
        }, 50)
      }
    } else if (event.target.type === "date") {
      // Add a timeout for date input so the user can finish entering the date
      setTimeout(() => {
        form.submit()
      }, 1000)
    } else {
      form.submit()
    }
  }

  isSelectSearch(el) {
    return el.tagName == "SELECT" && el.hasAttribute("data-search-methods")
  }

  _hightlightActiveFilters() {
    this._hightlightActiveNumericFilters()
    this._hightlightActiveSelectFilters()
    this._hightlightActiveDateRangeFilters()
  }

  _hightlightActiveNumericFilters() {
    const filters = this.element.querySelectorAll(
      ".numeric.input, .string.input"
    )
    filters.forEach((filter) => {
      const input = filter.querySelector("input[type='text']")
      if (input.value != "") {
        filter.classList.add("active")
      }
    })
  }

  _hightlightActiveSelectFilters() {
    const filters = this.element.querySelectorAll(
      ".select.input, .boolean.input"
    )
    filters.forEach((filter) => {
      const select = filter.querySelector("select")
      if (select.value != "") {
        filter.classList.add("active")
      }
    })
  }

  _hightlightActiveDateRangeFilters() {
    const filters = this.element.querySelectorAll(".date_range.input")
    filters.forEach((filter) => {
      const inputs = filter.querySelectorAll("input[type='date']")
      const startInput = inputs[0]
      const endInput = inputs[1]
      if (startInput.value != "" || endInput.value != "") {
        filter.classList.add("active")
      }
    })
  }

  _disableFormClearLinkWhenNoActiveFilters() {
    const activeFilters = this.element.querySelectorAll(".active")
    const formClear = document.querySelector(".filters-form-clear")
    if (activeFilters.length === 0) {
      formClear.classList.add("disabled")
    }
  }
}
