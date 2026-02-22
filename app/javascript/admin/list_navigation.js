// Shared keyboard-navigation logic for lists of [data-search-result] items.
//
// Both the global search modal and the handbook sidebar search need
// identical up/down/enter navigation over result lists. This mixin
// extracts that behaviour so neither controller duplicates it.
//
// Usage — mix into any Stimulus controller:
//
//   import { listNavigation } from "admin/list_navigation"
//
//   export default class extends Controller {
//     static targets = ["frame"]   // or "results" — the container
//
//     connect() {
//       Object.assign(this, listNavigation())
//     }
//   }
//
// The controller must provide a `resultItems` getter that returns the
// list of navigable DOM elements. Call `resetListSelection()` after new
// results load, and wire `navigateDown` / `navigateUp` / `selectCurrent`
// to keydown events.
//
// The mixin expects the host controller to have an `inputTarget` for
// returning focus on up-arrow from the first item.

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
