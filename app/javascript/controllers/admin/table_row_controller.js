import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { hide, addClass } from "components/utils"

export default class extends Controller {
  static targets = ["row"]

  navigate(event) {
    const row = event.target.closest("tr")
    if (!row) return

    const isLink = event.target.closest("a")
    if (isLink) return

    const isCheckbox = event.target.closest("input[type='checkbox']")
    if (isCheckbox) return

    event.preventDefault()
    event.stopPropagation()

    const url = this.getRowURL(row)
    if (url) {
      if (event.metaKey || event.ctrlKey) {
        window.open(url, "_blank")
      } else {
        Turbo.visit(url)
      }
    }
  }

  rowTargetConnected(element) {
    hide(element.querySelector("a[data-table-row='hidden']"))

    if (this.getRowURL(element)) {
      addClass(element, "cursor-pointer")
    }
  }

  focus(event) {
    const row = event.target.closest("tr")
    if (!row) return

    row.focus()
  }

  handleKeydown(event) {
    const row = event.target.closest("tr")
    if (!row) return

    if (event.key === "Enter") {
      this.navigate(event)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      const prevRow = this.getPreviousRow(row)
      if (prevRow) prevRow.focus()
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      const nextRow = this.getNextRow(row)
      if (nextRow) nextRow.focus()
    }
  }

  getRowURL(row) {
    const showLink = row.querySelector('a[aria-label="show"]')
    if (showLink) {
      return showLink.href
    }

    const editLink = row.querySelector('a[aria-label="edit"]')
    if (editLink) {
      return editLink.href
    }

    return null
  }

  getPreviousRow(currentRow) {
    const currentIndex = this.rowTargets.indexOf(currentRow)
    return currentIndex > 0 ? this.rowTargets[currentIndex - 1] : null
  }

  getNextRow(currentRow) {
    const currentIndex = this.rowTargets.indexOf(currentRow)
    return currentIndex < this.rowTargets.length - 1
      ? this.rowTargets[currentIndex + 1]
      : null
  }
}
