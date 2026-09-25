import { Controller } from "@hotwired/stimulus"

const RESULT_LIMIT = 20

export default class extends Controller {
  static values = {
    placeholder: String,
    empty: String,
    more: String,
    clear: String
  }

  connect() {
    if (!this.shouldEnhance()) return

    this.enhanced = true
    this.query = ""
    this.activeIndex = -1
    this.options = this.readOptions()
    this.onPointerDown = this.onPointerDown.bind(this)

    this.build()
    this.input.value = this.selectedLabel()
    this.toggleClear()
    document.addEventListener("pointerdown", this.onPointerDown)
  }

  disconnect() {
    if (!this.enhanced) return

    document.removeEventListener("pointerdown", this.onPointerDown)
    this.field?.remove()
    this.list?.remove()
    this.element.classList.remove("searchable-select-native")
    this.element.tabIndex = 0
    this.element.removeAttribute("aria-hidden")
  }

  shouldEnhance() {
    if (this.element.disabled) return false

    return this.enabledOptions().length >= 2
  }

  enabledOptions() {
    return [...this.element.options].filter((option) => option.value && !option.disabled)
  }

  readOptions() {
    return this.enabledOptions().map((option) => ({
      value: option.value,
      label: option.label,
      search: option.dataset.search || "",
      recent: option.dataset.recent === "true",
      group: option.parentElement?.tagName === "OPTGROUP" ? option.parentElement.label : null
    }))
  }

  build() {
    const parent = this.element.parentElement
    parent.classList.add("searchable-select")

    this.field = document.createElement("div")
    this.field.className = "searchable-select-field"

    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.className = "searchable-select-input"
    this.input.placeholder = this.placeholderValue
    this.input.setAttribute("role", "combobox")
    this.input.setAttribute("aria-autocomplete", "list")
    this.input.setAttribute("aria-expanded", "false")
    this.input.setAttribute("autocomplete", "off")
    this.input.setAttribute("autocorrect", "off")
    this.input.setAttribute("autocapitalize", "off")
    this.input.setAttribute("spellcheck", "false")
    this.input.setAttribute("enterkeyhint", "search")
    this.input.setAttribute("form", "")

    this.clearButton = document.createElement("button")
    this.clearButton.type = "button"
    this.clearButton.className = "searchable-select-clear"
    this.clearButton.hidden = true
    this.clearButton.setAttribute("aria-label", this.clearValue)
    this.clearButton.innerHTML =
      "<svg viewBox='0 0 24 24' aria-hidden='true'><path d='M18 6 6 18M6 6l12 12'/></svg>"

    this.list = document.createElement("div")
    this.list.className = "searchable-select-list"
    this.list.hidden = true
    this.list.setAttribute("role", "listbox")
    this.list.id = `${this.element.id}-listbox`
    this.input.setAttribute("aria-controls", this.list.id)

    this.field.append(this.input, this.clearButton)
    this.element.after(this.field, this.list)
    this.element.classList.add("searchable-select-native")
    this.element.tabIndex = -1
    this.element.setAttribute("aria-hidden", "true")

    this.input.id = `${this.element.id}-search`
    const label = this.element.labels?.[0]
    if (label) label.htmlFor = this.input.id

    this.input.addEventListener("focus", () => this.open())
    this.input.addEventListener("blur", () => this.onBlur())
    this.input.addEventListener("keydown", (event) => this.onKeydown(event))
    // Not a submitted field. Keystrokes must not look like form edits.
    this.input.addEventListener("input", (event) => {
      event.stopPropagation()
      this.onInput()
    })
    this.input.addEventListener("change", (event) => event.stopPropagation())
    this.clearButton.addEventListener("pointerdown", (event) => {
      event.preventDefault()
      this.clearSelection()
    })
    this.list.addEventListener("pointerdown", (event) => this.onListPointerDown(event))
  }

  open() {
    if (!this.list.hidden && this.query === "" && this.input.value === "") return

    this.query = ""
    this.activeIndex = 0
    this.input.value = ""
    this.toggleClear()
    if (this.recentOptions().length === 0) {
      this.hideList()
      return
    }

    this.showList()
  }

  onBlur() {
    setTimeout(() => {
      if (!this.field.isConnected) return
      if (this.field.contains(document.activeElement)) return

      this.close()
    }, 0)
  }

  close() {
    this.hideList()
    this.input.value = this.selectedLabel()
    this.query = ""
    this.toggleClear()
  }

  onInput() {
    this.query = this.input.value
    this.activeIndex = 0
    this.toggleClear()
    if (!this.normalize(this.query) && this.recentOptions().length === 0) {
      this.hideList()
      return
    }

    this.showList()
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.move(1)
      return
    }

    if (event.key === "ArrowUp") {
      event.preventDefault()
      this.move(-1)
      return
    }

    if (event.key === "Enter" && !this.list.hidden) {
      event.preventDefault()
      const match = this.matches()[this.activeIndex]
      if (match) this.choose(match)
    }
  }

  move(step) {
    if (!this.normalize(this.query) && this.recentOptions().length === 0) return

    const matches = this.matches()
    if (matches.length === 0) {
      this.showList()
      return
    }

    if (this.list.hidden) {
      this.showList()
      return
    }

    this.activeIndex = (this.activeIndex + step + matches.length) % matches.length
    this.render(matches)
  }

  onListPointerDown(event) {
    const row = event.target.closest("[data-value]")
    if (!row) return

    event.preventDefault()
    const match = this.options.find((option) => option.value === row.dataset.value)
    if (match) this.choose(match)
  }

  onPointerDown(event) {
    if (this.field.contains(event.target) || this.list.contains(event.target)) return

    this.close()
  }

  clearSelection() {
    this.element.value = ""
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
    this.input.value = ""
    this.query = ""
    this.activeIndex = 0
    this.toggleClear()
    if (this.recentOptions().length === 0) this.hideList()
    else this.showList()
    this.input.focus()
  }

  choose(option) {
    this.element.value = option.value
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
    this.input.value = option.label
    this.query = ""
    this.list.hidden = true
    this.input.setAttribute("aria-expanded", "false")
    this.input.removeAttribute("aria-activedescendant")
    this.toggleClear()
  }

  showList() {
    this.list.hidden = false
    this.input.setAttribute("aria-expanded", "true")
    this.render(this.matches())
  }

  hideList() {
    this.list.hidden = true
    this.input.setAttribute("aria-expanded", "false")
    this.input.removeAttribute("aria-activedescendant")
  }

  recentOptions() {
    return this.options.filter((option) => option.recent)
  }

  matches() {
    const tokens = this.normalize(this.query).split(/\s+/).filter(Boolean)
    if (tokens.length === 0) return this.recentOptions()

    return this.options.filter((option) => {
      const haystack = this.normalize(`${option.label} ${option.search}`)
      return tokens.every((token) => haystack.includes(token))
    })
  }

  render(matches) {
    const visible = matches.slice(0, RESULT_LIMIT)
    const truncated = matches.length > RESULT_LIMIT
    this.list.replaceChildren()

    if (visible.length === 0) {
      this.list.append(this.note(this.query ? this.emptyValue : this.placeholderValue))
      return
    }

    if (!this.query && visible[0]?.group) this.list.append(this.groupHeading(visible[0].group))

    visible.forEach((option, index) => {
      const row = document.createElement("div")
      row.className = "searchable-select-option"
      row.setAttribute("role", "option")
      row.dataset.value = option.value
      row.id = `${this.list.id}-option-${index}`
      row.textContent = option.label
      row.setAttribute("aria-selected", index === this.activeIndex ? "true" : "false")
      if (index === this.activeIndex) {
        row.classList.add("is-active")
        this.input.setAttribute("aria-activedescendant", row.id)
      }
      this.list.append(row)
    })

    if (truncated) this.list.append(this.note(this.moreValue))

    this.list.querySelector(".is-active")?.scrollIntoView({ block: "nearest" })
  }

  groupHeading(label) {
    const heading = document.createElement("div")
    heading.className = "searchable-select-group"
    heading.textContent = label
    return heading
  }

  note(text) {
    const row = document.createElement("div")
    row.className = "searchable-select-note"
    row.textContent = text
    return row
  }

  toggleClear() {
    this.clearButton.hidden = this.input.value === ""
  }

  selectedLabel() {
    const option = this.element.selectedOptions[0]
    if (!option?.value) return ""

    return option.label
  }

  normalize(text) {
    return text
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
  }
}
