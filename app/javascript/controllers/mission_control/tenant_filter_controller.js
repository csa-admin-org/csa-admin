import { Controller } from "@hotwired/stimulus"

// Live-filters tenants. One portal is selected and focused at a time.
// Up/Down move by tenant (Admin). Left/Right and Tab step through portals.
// Enter from the search field opens the selected Admin. ⌘/Ctrl+K focuses
// the filter.
export default class extends Controller {
  static targets = ["query", "list", "tenant", "link", "empty"]

  connect() {
    this.selectedIndex = -1
    this.filter()
    this.queryTarget.focus()
  }

  filter() {
    const q = this.queryTarget.value.trim().toLowerCase()
    let visible = 0

    for (const tenant of this.tenantTargets) {
      const haystack = (tenant.dataset.search || "").toLowerCase()
      const match = q === "" || haystack.includes(q)
      tenant.hidden = !match
      if (match) visible += 1
    }

    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0

    const adminLinks = this.#visibleAdminLinks()
    const focusOnLink = this.linkTargets.includes(document.activeElement)
    this.#selectIndex(adminLinks.length ? 0 : -1, { focus: focusOnLink })
  }

  selectLink(event) {
    const index = this.#visibleLinks().indexOf(event.currentTarget)
    if (index >= 0) this.#selectIndex(index, { focus: true })
  }

  focusQuery(event) {
    event?.preventDefault()
    this.queryTarget.focus()
    this.queryTarget.select()
  }

  keydown(event) {
    if (event.target !== this.queryTarget && !this.element.contains(event.target)) return

    if (event.key === "Tab") {
      if (!this.#visibleLinks().length) return
      event.preventDefault()
      this.#moveLink(event.shiftKey ? -1 : 1)
      return
    }

    if (event.key === "ArrowRight") {
      if (!this.#visibleLinks().length) return
      event.preventDefault()
      this.#moveLink(1)
      return
    }

    if (event.key === "ArrowLeft") {
      if (!this.#visibleLinks().length) return
      event.preventDefault()
      this.#moveLink(-1)
      return
    }

    const adminLinks = this.#visibleAdminLinks()
    if (!adminLinks.length) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.#moveTenant(1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.#moveTenant(-1)
    } else if (event.key === "Enter" && event.target === this.queryTarget) {
      event.preventDefault()
      const admin = this.#selectedAdminLink() || adminLinks[0]
      admin?.click()
    }
  }

  hideBrokenLogo(event) {
    event.currentTarget.hidden = true
  }

  #visibleLinks() {
    return this.linkTargets.filter(
      (link) => !link.closest("[data-tenant-filter-target='tenant']")?.hidden
    )
  }

  #visibleAdminLinks() {
    return this.#visibleLinks().filter((link) => link.dataset.portal === "admin")
  }

  #selectedAdminLink() {
    const selected = this.#visibleLinks()[this.selectedIndex]
    if (!selected) return null
    return selected
      .closest("[data-tenant-filter-target='tenant']")
      ?.querySelector('[data-portal="admin"]')
  }

  #tenantAdminLink(link) {
    return link
      .closest("[data-tenant-filter-target='tenant']")
      ?.querySelector('[data-portal="admin"]')
  }

  #moveTenant(delta) {
    const adminLinks = this.#visibleAdminLinks()
    if (!adminLinks.length) return

    const links = this.#visibleLinks()
    const onQuery = document.activeElement === this.queryTarget

    // From the filter: enter the list on the current Admin (don't skip a row).
    if (onQuery) {
      const admin = this.#selectedAdminLink() || adminLinks[0]
      this.#selectIndex(links.indexOf(admin), { focus: true })
      return
    }

    const currentAdmin =
      this.#tenantAdminLink(document.activeElement) || this.#selectedAdminLink() || adminLinks[0]
    const current = Math.max(0, adminLinks.indexOf(currentAdmin))
    const next = Math.min(Math.max(current + delta, 0), adminLinks.length - 1)
    this.#selectIndex(links.indexOf(adminLinks[next]), { focus: true })
  }

  #moveLink(delta) {
    const links = this.#visibleLinks()
    if (!links.length) return

    const active = document.activeElement
    const onQuery = active === this.queryTarget
    const focusedIndex = links.indexOf(active)

    let next
    if (onQuery) {
      next = delta > 0 ? Math.max(0, this.selectedIndex) : links.length - 1
    } else if (focusedIndex >= 0) {
      next = focusedIndex + delta
      if (next < 0 || next >= links.length) {
        this.focusQuery()
        return
      }
    } else {
      next = delta > 0 ? Math.max(0, this.selectedIndex) : links.length - 1
    }

    this.#selectIndex(next, { focus: true })
  }

  #selectIndex(index, { focus = false } = {}) {
    const links = this.#visibleLinks()
    this.selectedIndex = index

    for (const link of this.linkTargets) {
      link.classList.remove("is-selected")
      link.closest(".mc-tenant")?.classList.remove("is-active")
    }

    const selected = links[index]
    if (!selected) return

    selected.classList.add("is-selected")
    selected.closest(".mc-tenant")?.classList.add("is-active")
    selected.scrollIntoView({ block: "nearest" })

    if (focus) selected.focus({ preventScroll: true })
  }
}
