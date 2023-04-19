import { Controller } from "@hotwired/stimulus"
import { hide, show } from "components/utils"
import flatpickr from "flatpickr"
import { French } from "flatpickr/dist/l10n/fr"
import { German } from "flatpickr/dist/l10n/de"
import { Italian } from "flatpickr/dist/l10n/it"

export default class extends Controller {
  static get targets() {
    return ["calendar", "input"]
  }
  static get values() {
    return {
      dates: Array,
      nonFullDates: Array,
      defaultDate: String,
    }
  }

  connect() {
    this._selectDate(this.defaultDateValue)
    this.application.calendar = flatpickr(this.calendarTarget, {
      locale: this._flatpickrLocale(),
      defaultDate: this.defaultDateValue,
      minDate: this.datesValue[0],
      maxDate: this.datesValue[this.datesValue.length - 1],
      enable: this.datesValue,
      inline: true,
      onChange: (selectedDates, dateStr, instance) => {
        this._selectDate(dateStr)
      },
      onMonthChange: (selectedDates, dateStr, instance) => {
        this._monthOrYearChanged(this.datesValue, instance)
      },
      onYearChange: (selectedDates, dateStr, instance) => {
        this._monthOrYearChanged(this.datesValue, instance)
      },
      onDayCreate: (dObj, dStr, fp, dayElem) => {
        var offset = dayElem.dateObj.getTimezoneOffset()
        var date = new Date(dayElem.dateObj.getTime() - (offset * 60 * 1000))
        var dateStr = date.toISOString().substring(0, 10)
        if (this.nonFullDatesValue.find(e => e === dateStr)) {
          dayElem.className += ' not-full'
        }
      }
    })
  }

  disconnect() {
    this.application.calendar.destroy()
  }

  _selectDate(dateText) {
    for (const input of this.inputTargets) {
      hide(input.closest("span.checkbox"))
      input.checked = false
    }
    const dateInputs = this.inputTargets.filter(
      (input) => input.dataset.date == dateText
    )
    if (dateInputs.length > 0) {
      for (const input of dateInputs) {
        show(input.closest("span.checkbox"))
      }
      if (dateInputs.every((input) => !input.checked && !input.disabled)) {
        dateInputs[0].checked = true
      }
    }
  }

  _monthOrYearChanged(dates, calendar) {
    const currentMonthStr = String("00" + (calendar.currentMonth + 1)).slice(-2)
    const yearMonth = `${calendar.currentYear}-${currentMonthStr}`
    const date = dates.filter((d) => d.startsWith(yearMonth))[0]

    calendar.setDate(date)
    this._selectDate(date)
  }

  _flatpickrLocale() {
    const locale = document.documentElement.lang
    if (locale === "de") {
      return German
    } else if (locale === "it") {
      return Italian
    } else {
      return French
    }
  }
}
