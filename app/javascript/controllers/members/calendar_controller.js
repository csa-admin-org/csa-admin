import { Controller } from "@hotwired/stimulus"
import { prop, hide, show } from "components/utils"
import flatpickr from "flatpickr"
import { French } from "flatpickr/dist/l10n/fr"
import { German } from "flatpickr/dist/l10n/de"
import { Italian } from "flatpickr/dist/l10n/it"

export default class extends Controller {
  static get targets() {
    return ["calendar", "input", "submit"]
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
        this._monthOrYearChanged(selectedDates, this.datesValue, instance)
      },
      onYearChange: (selectedDates, dateStr, instance) => {
        this._monthOrYearChanged(selectedDates, this.datesValue, instance)
      },
      onDayCreate: (dObj, dStr, fp, dayElem) => {
        var dateStr = this._dateToISO(dayElem.dateObj)
        if (this.nonFullDatesValue.includes(dateStr)) {
          dayElem.className += ' not-full'
        }
      }
    })
  }

  disconnect() {
    this.application.calendar.destroy()
  }

  filterDates(event) {
    var dates = event.target.value ? event.target.value.split(", ") : this.datesValue
    this.application.calendar.set("enable", dates)
    this.application.calendar.set("minDate", dates[0])
    this.application.calendar.set("maxDate", dates[dates.length - 1])
    this.application.calendar.set("onDayCreate", (dObj, dStr, fp, dayElem) => {
      var dateStr = this._dateToISO(dayElem.dateObj)
      if (this.nonFullDatesValue.includes(dateStr) && dates.includes(dateStr)) {
        dayElem.className += ' not-full'
      }
    })
    this.application.calendar.set("onMonthChange", (selectedDates, dateStr, instance) => {
      this._monthOrYearChanged(selectedDates, dates, instance)
    })
    this.application.calendar.set("onYearChange", (selectedDates, dateStr, instance) => {
      this._monthOrYearChanged(selectedDates, dates, instance)
    })
    this.application.calendar.set("defaultDate", dates[0])
    this.application.calendar.setDate(dates[0])
    this._selectDate(dates[0])
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
      prop(this.submitTarget, "disabled", (dateInputs.every((input) => input.disabled)))
    }
  }

  _monthOrYearChanged(selectedDates, dates, calendar) {
    const currentMonthStr = String("00" + (calendar.currentMonth + 1)).slice(-2)
    const yearMonth = `${calendar.currentYear}-${currentMonthStr}`
    const currentDates = dates.filter((d) => d.startsWith(yearMonth))
    const selectedDate = this._dateToISO(selectedDates[0])

    if (currentDates.find(d => d === selectedDate)) {
      this._selectDate(selectedDate)
    } else {
      calendar.setDate(currentDates[0])
      this._selectDate(currentDates[0])
    }
  }

  _dateToISO(date) {
    const offset = date.getTimezoneOffset()
    return new Date(date.getTime() - (offset * 60 * 1000)).toISOString().substring(0, 10)
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
