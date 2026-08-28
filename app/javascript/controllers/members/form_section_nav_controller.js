import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section"]
  static values = {
    navigationLabel: String,
    sectionLabel: String
  }

  connect() {
    if (this.sectionTargets.length < 2) return

    this.nav = this.#buildNav()
    this.element.prepend(this.nav)
    this.#activeIndex = 0
    this.#updateActiveLink(0)
    this.#observeSections()
    this.#observeVisibility()
    this.#observeNavHeight()

    this.#scrollTicking = false
    this.#scrollHandler = () => {
      if (!this.#scrollTicking) {
        requestAnimationFrame(() => {
          this.#checkBottom()
          this.#scrollTicking = false
        })
        this.#scrollTicking = true
      }
    }
    this.#resizeHandler = () => this.#syncNavHeight()
    window.addEventListener("scroll", this.#scrollHandler, { passive: true })
    window.addEventListener("resize", this.#resizeHandler, { passive: true })
  }

  disconnect() {
    this.#observer?.disconnect()
    this.#visibilityObserver?.disconnect()
    this.#navResizeObserver?.disconnect()
    this.nav?.remove()
    this.element.style.removeProperty("--member-form-section-nav-height")
    if (this.#scrollHandler) {
      window.removeEventListener("scroll", this.#scrollHandler)
    }
    if (this.#resizeHandler) {
      window.removeEventListener("resize", this.#resizeHandler)
    }
  }

  // --- Private ---

  #activeIndex = 0
  #scrollTicking = false
  #scrollHandler = null
  #resizeHandler = null
  #observer = null
  #visibilityObserver = null
  #navResizeObserver = null
  #links = []
  #visibleSections = new Set()

  #buildNav() {
    const nav = document.createElement("nav")
    nav.setAttribute("aria-label", this.navigationLabelValue)
    nav.className = "member-form-section-nav is-hidden"

    const list = document.createElement("ol")
    list.className = "member-form-section-nav-list"

    this.#links = this.sectionTargets.map((section, index) => {
      const legend = section.querySelector(":scope > legend")
      const label =
        legend?.textContent?.trim() || this.sectionLabelValue.replace("%{number}", index + 1)

      const li = document.createElement("li")
      li.className = "member-form-section-nav-item"

      if (index > 0) {
        const separator = document.createElement("span")
        separator.textContent = "›"
        separator.className = "member-form-section-nav-sep"
        separator.setAttribute("aria-hidden", "true")
        li.appendChild(separator)
      }

      const link = document.createElement("a")
      link.href = `#form-section-${index}`
      link.textContent = label
      link.className = this.#linkBaseClasses()
      link.addEventListener("click", (e) => {
        e.preventDefault()
        this.#scrollToSection(index)
      })

      section.id = `form-section-${index}`

      li.appendChild(link)
      list.appendChild(li)

      return link
    })

    nav.appendChild(list)
    return nav
  }

  #observeVisibility() {
    const firstLegend = this.sectionTargets[0]?.querySelector(":scope > legend")
    if (!firstLegend) return

    this.#visibilityObserver = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          this.nav.classList.add("is-hidden")
        } else {
          this.nav.classList.remove("is-hidden")
        }

        requestAnimationFrame(() => this.#syncNavHeight())
      },
      { root: null, threshold: 0 }
    )

    this.#visibilityObserver.observe(firstLegend)
  }

  #observeNavHeight() {
    this.#navResizeObserver = new ResizeObserver(() => this.#syncNavHeight())
    this.#navResizeObserver.observe(this.nav)
    this.#syncNavHeight()
  }

  #syncNavHeight() {
    const height = this.nav && !this.nav.classList.contains("is-hidden") ? this.nav.offsetHeight : 0
    this.element.style.setProperty("--member-form-section-nav-height", `${height}px`)
  }

  #observeSections() {
    this.#observer = new IntersectionObserver(
      (entries) => {
        this.#handleIntersections(entries)
      },
      {
        root: null,
        rootMargin: "-80px 0px -60% 0px",
        threshold: 0
      }
    )

    this.#visibleSections = new Set()

    this.sectionTargets.forEach((section) => {
      this.#observer.observe(section)
    })
  }

  #handleIntersections(entries) {
    entries.forEach((entry) => {
      const index = this.sectionTargets.indexOf(entry.target)
      if (index === -1) return

      if (entry.isIntersecting) {
        this.#visibleSections.add(index)
      } else {
        this.#visibleSections.delete(index)
      }
    })

    this.#updateFromVisibility()
  }

  #checkBottom() {
    const atBottom = window.innerHeight + window.scrollY >= document.body.scrollHeight - 50

    if (atBottom) {
      const lastIndex = this.sectionTargets.length - 1
      if (this.#activeIndex !== lastIndex) {
        this.#activeIndex = lastIndex
        this.#updateActiveLink(lastIndex)
      }
    } else {
      this.#updateFromVisibility()
    }
  }

  #updateFromVisibility() {
    if (this.#visibleSections.size > 0) {
      const topmost = Math.min(...this.#visibleSections)
      if (topmost !== this.#activeIndex) {
        this.#activeIndex = topmost
        this.#updateActiveLink(topmost)
      }
    }
  }

  #updateActiveLink(activeIndex) {
    this.#links.forEach((link, index) => {
      if (index === activeIndex) {
        link.className = this.#linkActiveClasses()
      } else {
        link.className = this.#linkBaseClasses()
      }
    })
  }

  #scrollToSection(index) {
    const section = this.sectionTargets[index]
    if (!section) return

    const navHeight = this.nav?.offsetHeight || 0
    const sectionTop = section.getBoundingClientRect().top + window.scrollY - navHeight - 16

    window.scrollTo({ top: sectionTop, behavior: "smooth" })
  }

  #linkBaseClasses() {
    return "member-form-section-nav-link"
  }

  #linkActiveClasses() {
    return "member-form-section-nav-link is-active"
  }
}
