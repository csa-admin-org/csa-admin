import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  update(event) {
    const selectId = event.params.target
    const select = document.getElementById(selectId)
    const values = event.currentTarget.selectedOptions[0].dataset.formSelectOptionsValuesParam.split(',')

    Array.from(select.options).forEach((option) => {
      if(values.includes(option.value)) {
        option.disabled = false;
        option.hidden = false;
      } else {
        option.disabled = true;
        option.hidden = true;
        option.selected = false;
      }
    })
    Array.from(select.options).find((o) => !o.disabled).selected = true;
  }
}
