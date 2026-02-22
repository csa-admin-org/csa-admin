import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    const url = new URL(window.location)
    const query = url.searchParams.get("highlight")

    if (!query || query.trim().length < 3) return
    if (!this.hasContentTarget) return

    const terms = this.extractTerms(query)
    if (terms.length === 0) return

    this.highlightTerms(this.contentTarget, terms)

    // If a URL hash anchor is present, scroll to it (explicit navigation
    // intent takes priority over highlight position). Otherwise fall back
    // to the first highlighted match.
    const hash = url.hash?.slice(1)
    const anchorTarget = hash && document.getElementById(hash)
    const scrollTarget =
      anchorTarget || this.contentTarget.querySelector("mark")

    if (scrollTarget) {
      requestAnimationFrame(() => {
        scrollTarget.scrollIntoView({
          behavior: "smooth",
          block: anchorTarget ? "start" : "center"
        })
      })
    }

    // Clean up the URL so refreshing doesn't re-highlight
    url.searchParams.delete("highlight")
    history.replaceState(history.state, "", url)
  }

  extractTerms(query) {
    return query
      .trim()
      .split(/\s+/)
      .map((t) => this.normalize(t))
      .filter((t) => t.length >= 3)
  }

  // Mirrors server-side SearchEntry.normalize_text for matching purposes.
  normalize(text) {
    return text
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
  }

  highlightTerms(container, terms) {
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, {
      acceptNode: (node) => {
        const parent = node.parentElement
        if (!parent) return NodeFilter.FILTER_REJECT
        const tag = parent.tagName.toLowerCase()
        if (
          tag === "code" ||
          tag === "pre" ||
          tag === "mark" ||
          tag === "script" ||
          tag === "style"
        ) {
          return NodeFilter.FILTER_REJECT
        }
        return NodeFilter.FILTER_ACCEPT
      }
    })

    // Collect first to avoid modifying the tree while iterating.
    const textNodes = []
    while (walker.nextNode()) {
      textNodes.push(walker.currentNode)
    }

    for (const textNode of textNodes) {
      this.highlightTextNode(textNode, terms)
    }
  }

  highlightTextNode(textNode, terms) {
    const originalText = textNode.textContent
    if (!originalText || originalText.trim().length === 0) return

    const normalized = []
    const indexMap = []

    for (let i = 0; i < originalText.length; i++) {
      const nfd = originalText[i].normalize("NFD")
      for (const char of nfd) {
        if (/[\u0300-\u036f]/.test(char)) continue
        normalized.push(char.toLowerCase())
        indexMap.push(i)
      }
    }

    const normalizedStr = normalized.join("")

    const ranges = []

    for (const term of terms) {
      let searchFrom = 0
      while (searchFrom < normalizedStr.length) {
        const pos = normalizedStr.indexOf(term, searchFrom)
        if (pos === -1) break

        const origStart = indexMap[pos]
        const lastNormIdx = pos + term.length - 1
        // The original end is one past the last matched original character
        const origEnd =
          lastNormIdx + 1 < indexMap.length
            ? indexMap[lastNormIdx] + 1
            : originalText.length

        ranges.push([origStart, origEnd])
        searchFrom = pos + 1
      }
    }

    if (ranges.length === 0) return

    ranges.sort((a, b) => a[0] - b[0] || a[1] - b[1])
    const merged = [ranges[0]]
    for (let i = 1; i < ranges.length; i++) {
      const last = merged[merged.length - 1]
      if (ranges[i][0] <= last[1]) {
        last[1] = Math.max(last[1], ranges[i][1])
      } else {
        merged.push(ranges[i])
      }
    }

    const fragment = document.createDocumentFragment()
    let cursor = 0

    for (const [start, end] of merged) {
      if (cursor < start) {
        fragment.appendChild(
          document.createTextNode(originalText.slice(cursor, start))
        )
      }
      const mark = document.createElement("mark")
      mark.textContent = originalText.slice(start, end)
      fragment.appendChild(mark)
      cursor = end
    }

    if (cursor < originalText.length) {
      fragment.appendChild(document.createTextNode(originalText.slice(cursor)))
    }

    textNode.parentNode.replaceChild(fragment, textNode)
  }
}
