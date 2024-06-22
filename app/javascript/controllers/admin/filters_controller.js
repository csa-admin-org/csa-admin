import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    const form = event.target.closest('form')
    if (!form) return

    if (this.isSelectSearch(event.target)) {
      if (event.target.nextElementSibling.value != '') {
        // Let the select_and_search active admin JS do its job first
        setTimeout(() => { form.submit() }, 50)
      }
    } else {
      form.submit()
    }
  }

  isSelectSearch(el) {
    return (el.tagName == 'SELECT' && el.hasAttribute('data-search-methods'))
  }
}
