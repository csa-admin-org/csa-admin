import { Controller } from "@hotwired/stimulus"
import { prop, hide, show } from "components/utils"

const TWO_MONTHS = "(width >= 48rem)"

export default class extends Controller {
  static get targets() {
    return ["calendar", "input", "submit"]
  }
  static get values() {
    return {
      dates: Array,
      nonFullDates: Array,
      defaultDate: String
    }
  }

  async connect() {
    this.generation = (this.generation || 0) + 1
    const generation = this.generation
    this.enabledDates = this.datesValue
    this._selectDate(this.defaultDateValue)

    this.media = window.matchMedia(TWO_MONTHS)
    this._onMedia = () => this._applyLayout()

    const { Calendar } = await import("vanilla-calendar-pro")
    if (generation !== this.generation) return

    this.host = document.createElement("div")
    this.calendarTarget.append(this.host)

    const twoMonths = this.media.matches
    this.calendar = new Calendar(this.host, {
      ...this._layoutParams(twoMonths),
      locale: document.documentElement.lang,
      firstWeekday: 1,
      selectedTheme: this._selectedTheme(),
      selectedWeekends: [],
      selectionMonthsMode: "only-arrows",
      selectionYearsMode: "only-arrows",
      disableAllDates: true,
      displayDisabledDates: true,
      displayDatesOutside: false,
      enableDates: this.enabledDates,
      enableDateToggle: false,
      enableJumpToSelectedDate: true,
      selectedDates: this.selectedDate ? [this.selectedDate] : [],
      dateMin: this.enabledDates[0],
      dateMax: this.enabledDates[this.enabledDates.length - 1],
      onClickDate: (self) => this._onDateClick(self),
      onClickArrow: (self) => this._jumpIfNeeded(self),
      onCreateDateEls: (_self, dateEl) => this._markRemaining(dateEl)
    })
    this.calendar.init()
    this.media.addEventListener("change", this._onMedia)
  }

  disconnect() {
    this.generation = (this.generation || 0) + 1
    this.media?.removeEventListener("change", this._onMedia)
    this._destroyCalendar()
  }

  filterDates(event) {
    this.enabledDates = event.target.value ? event.target.value.split(", ") : this.datesValue
    const next = this.enabledDates[0]
    if (this.calendar) {
      this.calendar.set(
        {
          enableDates: this.enabledDates,
          selectedDates: next ? [next] : [],
          dateMin: this.enabledDates[0],
          dateMax: this.enabledDates[this.enabledDates.length - 1]
        },
        { year: true, month: true, dates: true }
      )
    }
    this._selectDate(next)
  }

  _layoutParams(twoMonths) {
    if (twoMonths) {
      return { type: "multiple", displayMonthsCount: 2 }
    }
    return { type: "default", displayMonthsCount: 1 }
  }

  _applyLayout() {
    this.calendar.set(this._layoutParams(this.media.matches), {
      year: false,
      month: false,
      dates: false
    })
  }

  _selectedTheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }

  _onDateClick(calendar) {
    const date = calendar.context.selectedDates[0]
    if (!date || date === this.selectedDate) return
    this._selectDate(date)
  }

  _markRemaining(dateEl) {
    const date = dateEl.dataset.vcDate
    if (this.nonFullDatesValue.includes(date) && this.enabledDates.includes(date)) {
      dateEl.classList.add("not-full")
    }
  }

  _visibleYearMonths(calendar) {
    const count = calendar.context.displayMonthsCount || 1
    const months = []
    for (let i = 0; i < count; i++) {
      const date = new Date(calendar.context.selectedYear, calendar.context.selectedMonth + i, 1)
      const month = String(date.getMonth() + 1).padStart(2, "0")
      months.push(`${date.getFullYear()}-${month}`)
    }
    return months
  }

  _jumpIfNeeded(calendar) {
    const selected = calendar.context.selectedDates[0]
    const visible = this._visibleYearMonths(calendar)
    if (selected && visible.some((prefix) => selected.startsWith(prefix))) {
      if (this.selectedDate !== selected) this._selectDate(selected)
      return
    }

    const next = this.enabledDates.find((date) => visible.some((prefix) => date.startsWith(prefix)))
    if (next) {
      calendar.set({ selectedDates: [next] }, { year: false, month: false, dates: true })
    }
    this._selectDate(next)
  }

  _selectDate(dateText) {
    this.selectedDate = dateText
    for (const input of this.inputTargets) {
      hide(input.closest("span.checkbox"))
      input.checked = false
    }
    const dateInputs = this.inputTargets.filter((input) => input.dataset.date == dateText)
    if (dateInputs.length === 0) {
      prop(this.submitTarget, "disabled", true)
      return
    }

    for (const input of dateInputs) {
      show(input.closest("span.checkbox"))
    }
    if (dateInputs.every((input) => !input.checked && !input.disabled)) {
      dateInputs[0].checked = true
    }
    prop(
      this.submitTarget,
      "disabled",
      dateInputs.every((input) => input.disabled)
    )
  }

  _destroyCalendar() {
    if (this.calendar?.context?.isInit && !this.calendar.context.isDestroyed) {
      this.calendar.destroy()
    }
    this.calendar = null
    this.calendarTarget.replaceChildren()
    this.host = null
  }
}
