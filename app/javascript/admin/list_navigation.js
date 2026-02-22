export function listNavigation() {
  return {
    selectedIndex: -1,

    resetListSelection() {
      const items = this.resultItems
      if (items.length > 0) {
        this.selectedIndex = 0
        this._highlightItem(items)
      } else {
        this.selectedIndex = -1
      }
    },

    navigateDown(event) {
      const items = this.resultItems
      if (items.length === 0) return

      event.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
      this._highlightItem(items)
    },

    navigateUp(event) {
      const items = this.resultItems
      if (items.length === 0) return

      event.preventDefault()

      if (this.selectedIndex <= 0) {
        this.selectedIndex = -1
        this._clearHighlight(items)
        this.inputTarget.focus()
        return
      }

      this.selectedIndex = this.selectedIndex - 1
      this._highlightItem(items)
    },

    selectCurrent(event) {
      const items = this.resultItems
      const index = this.selectedIndex
      if (index >= 0 && index < items.length) {
        event.preventDefault()
        items[index].click()
      }
    },

    _highlightItem(items) {
      items.forEach((item, index) => {
        if (index === this.selectedIndex) {
          item.classList.add("search-selected")
          item.scrollIntoView({ block: "nearest" })
        } else {
          item.classList.remove("search-selected")
        }
      })
    },

    _clearHighlight(items) {
      items.forEach((item) => {
        item.classList.remove("search-selected")
      })
    }
  }
}
