import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section"]

  connect() {
    if (this.sectionTargets.length < 2) return

    this.nav = this.#buildNav()
    this.element.prepend(this.nav)
    this.#activeIndex = 0
    this.#updateActiveLink(0)
    this.#observeSections()
    this.#observeVisibility()

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
    window.addEventListener("scroll", this.#scrollHandler, { passive: true })
  }

  disconnect() {
    this.#observer?.disconnect()
    this.#visibilityObserver?.disconnect()
    this.nav?.remove()
    if (this.#scrollHandler) {
      window.removeEventListener("scroll", this.#scrollHandler)
    }
  }

  // --- Private ---

  #activeIndex = 0
  #scrollTicking = false
  #scrollHandler = null
  #observer = null
  #visibilityObserver = null
  #links = []
  #visibleSections = new Set()

  #buildNav() {
    const nav = document.createElement("nav")
    nav.setAttribute("aria-label", "Form sections")
    nav.className = [
      "sticky top-0 z-10",
      "hidden flex-row items-center justify-center gap-1",
      "bg-white/90 dark:bg-black/90 backdrop-blur-sm",
      "-mx-4 px-4 py-2",
      "border-b border-gray-100 dark:border-gray-800",
      "print:hidden"
    ].join(" ")

    const list = document.createElement("ol")
    list.className =
      "flex flex-row flex-wrap items-center justify-center gap-x-1 gap-y-0.5"

    this.#links = this.sectionTargets.map((section, index) => {
      const legend = section.querySelector(":scope > legend")
      const label = legend?.textContent?.trim() || `Section ${index + 1}`

      const li = document.createElement("li")
      li.className = "flex items-center"

      if (index > 0) {
        const separator = document.createElement("span")
        separator.textContent = "›"
        separator.className =
          "mr-1 text-xs text-gray-300 dark:text-gray-600 select-none"
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
          this.nav.classList.add("hidden")
          this.nav.classList.remove("flex")
        } else {
          this.nav.classList.remove("hidden")
          this.nav.classList.add("flex")
        }
      },
      { root: null, threshold: 0 }
    )

    this.#visibilityObserver.observe(firstLegend)
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
    const atBottom =
      window.innerHeight + window.scrollY >= document.body.scrollHeight - 50

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
    const sectionTop =
      section.getBoundingClientRect().top + window.scrollY - navHeight - 16

    window.scrollTo({ top: sectionTop, behavior: "smooth" })
  }

  #linkBaseClasses() {
    return [
      "px-2 py-1 rounded-md",
      "text-xs font-medium",
      "text-gray-400 dark:text-gray-500",
      "hover:text-gray-600 dark:hover:text-gray-300",
      "transition-colors duration-150"
    ].join(" ")
  }

  #linkActiveClasses() {
    return [
      "px-2 py-1 rounded-md",
      "text-xs font-medium",
      "text-gray-700 dark:text-gray-200",
      "bg-gray-100 dark:bg-gray-800",
      "transition-colors duration-150"
    ].join(" ")
  }
}
