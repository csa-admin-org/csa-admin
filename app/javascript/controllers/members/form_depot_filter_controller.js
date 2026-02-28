import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["input", "clearButton", "group", "noResults"]
  }

  connect() {
    this.originalContents = new Map()

    for (const group of this.groupTargets) {
      const items = group.querySelectorAll("input[data-depot-name]")
      for (const item of items) {
        const content = this.contentFor(item)
        if (content) {
          this.originalContents.set(item, content.innerHTML)
        }
      }
    }
  }

  disconnect() {
    this.originalContents = null
  }

  filter() {
    const query = this.normalizeText(this.inputTarget.value)

    this.toggleClearButton(query !== "")

    if (query === "") {
      this.showAll()
      return
    }

    let totalVisible = 0

    for (const group of this.groupTargets) {
      const items = group.querySelectorAll("input[data-depot-name]")
      let groupVisible = 0

      for (const item of items) {
        const name = this.normalizeText(item.dataset.depotName || "")
        const city = this.normalizeText(item.dataset.depotCity || "")
        const zip = item.dataset.depotZip || ""
        const address = this.normalizeText(item.dataset.depotAddress || "")
        const wrapper = item.closest("span")

        const matches =
          name.includes(query) ||
          city.includes(query) ||
          zip.includes(query) ||
          address.includes(query)

        if (matches) {
          if (wrapper) wrapper.style.display = ""
          this.highlightContent(item, query)
          groupVisible++
        } else if (item.checked) {
          if (wrapper) wrapper.style.display = ""
          this.restoreContent(item)
          groupVisible++
        } else {
          if (wrapper) wrapper.style.display = "none"
          this.restoreContent(item)
        }
      }

      const header = group.querySelector("[data-depot-group-header]")
      if (header) {
        header.style.display = groupVisible === 0 ? "none" : ""
      }

      totalVisible += groupVisible
    }

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.toggle("hidden", totalVisible > 0)
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.toggleClearButton(false)
    this.showAll()
    this.inputTarget.focus()
  }

  showAll() {
    for (const group of this.groupTargets) {
      const items = group.querySelectorAll("input[data-depot-name]")
      for (const item of items) {
        const wrapper = item.closest("span")
        if (wrapper) wrapper.style.display = ""
        this.restoreContent(item)
      }
      const header = group.querySelector("[data-depot-group-header]")
      if (header) {
        header.style.display = ""
      }
    }
    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.add("hidden")
    }
  }

  highlightContent(item, query) {
    const content = this.contentFor(item)
    if (!content) return

    const original = this.originalContents.get(item)
    if (!original) return

    // Build a regex that matches the query accent-insensitively.
    // For each character in the normalized query, we match either
    // the character itself or the character followed by combining marks.
    const combiningMarks = "\u0300-\u036f"
    const pattern = query
      .split("")
      .map((ch) => this.escapeRegExp(ch) + `[${combiningMarks}]*`)
      .join("")
    const regex = new RegExp(pattern, "gi")

    // Apply highlighting only to text content, preserving HTML tags.
    // Split the original HTML into tags and text segments, only apply
    // the regex replacement on text segments.
    content.innerHTML = original.replace(
      /(<[^>]+>)|([^<]+)/g,
      (_match, tag, text) => {
        if (tag) return tag

        // Normalize the text to NFD so combining marks are separate,
        // apply the highlight regex, then normalize back to NFC.
        return text
          .normalize("NFD")
          .replace(regex, "<mark>$&</mark>")
          .normalize("NFC")
      }
    )
  }

  restoreContent(item) {
    const content = this.contentFor(item)
    if (!content) return

    const original = this.originalContents.get(item)
    if (original) {
      content.innerHTML = original
    }
  }

  // Target the collection_text div inside the label, not the label itself,
  // to avoid destroying/recreating the input element with innerHTML.
  contentFor(item) {
    return item.closest("label")?.querySelector("div")
  }

  toggleClearButton(visible) {
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.classList.toggle("hidden", !visible)
      this.clearButtonTarget.classList.toggle("flex", visible)
    }
  }

  escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  }

  normalizeText(text) {
    return text
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim()
  }
}
