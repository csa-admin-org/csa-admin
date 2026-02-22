import { Controller } from "@hotwired/stimulus"

// Highlights search terms in the handbook page content when arriving
// from a sidebar search result link with a `?highlight=...` query param.
//
// Walks all text nodes inside the target element and wraps matching
// substrings in <mark> tags. Uses Unicode-aware transliteration (same
// approach as the server-side SearchEntry.normalize_text) so that
// accent-insensitive matching works (e.g. "eligible" highlights "éligible").
//
// After highlighting, scrolls the first <mark> into view and cleans up
// the URL param so that a page refresh doesn't re-highlight.
//
// Targets:
//   content – the container element whose text nodes will be searched
//
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

    // Scroll the first highlighted match into view (below any sticky header)
    const firstMark = this.contentTarget.querySelector("mark")
    if (firstMark) {
      requestAnimationFrame(() => {
        firstMark.scrollIntoView({ behavior: "smooth", block: "center" })
      })
    }

    // Clean up the URL so refreshing doesn't re-highlight
    url.searchParams.delete("highlight")
    history.replaceState(history.state, "", url)
  }

  // Split query into normalized terms (transliterated + lowercased),
  // filtering out terms shorter than 3 characters.
  extractTerms(query) {
    return query
      .trim()
      .split(/\s+/)
      .map((t) => this.normalize(t))
      .filter((t) => t.length >= 3)
  }

  // Simple transliteration: normalize Unicode to NFD form, strip combining
  // diacritical marks, then lowercase. This mirrors the server-side
  // SearchEntry.normalize_text behaviour for matching purposes.
  normalize(text) {
    return text
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
  }

  // Walk all text nodes in the container and wrap matching substrings
  // in <mark> tags.
  highlightTerms(container, terms) {
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, {
      acceptNode: (node) => {
        // Skip nodes inside <code>, <pre>, <mark>, or <script> elements
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

    // Collect text nodes first to avoid modifying the tree while walking
    const textNodes = []
    while (walker.nextNode()) {
      textNodes.push(walker.currentNode)
    }

    for (const textNode of textNodes) {
      this.highlightTextNode(textNode, terms)
    }
  }

  // Find all term matches in a text node and replace it with a mix of
  // text and <mark> elements. Matches are found against the normalized
  // (transliterated) version of the text but applied to the original
  // characters, preserving accents and casing.
  highlightTextNode(textNode, terms) {
    const originalText = textNode.textContent
    if (!originalText || originalText.trim().length === 0) return

    // Build a character-by-character mapping from original text to
    // normalized text, so we can map match positions back accurately.
    const normalized = []
    const indexMap = [] // indexMap[normalizedIndex] = originalIndex

    for (let i = 0; i < originalText.length; i++) {
      const nfd = originalText[i].normalize("NFD")
      for (const char of nfd) {
        // Skip combining diacritical marks in normalized form
        if (/[\u0300-\u036f]/.test(char)) continue
        normalized.push(char.toLowerCase())
        indexMap.push(i)
      }
    }

    const normalizedStr = normalized.join("")

    // Find all match ranges [start, end) in normalized positions
    const ranges = [] // Array of [origStart, origEnd] in original text indices

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

    // Merge overlapping/adjacent ranges
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

    // Build replacement fragment
    const fragment = document.createDocumentFragment()
    let cursor = 0

    for (const [start, end] of merged) {
      // Text before the match
      if (cursor < start) {
        fragment.appendChild(
          document.createTextNode(originalText.slice(cursor, start))
        )
      }
      // The highlighted match
      const mark = document.createElement("mark")
      mark.textContent = originalText.slice(start, end)
      fragment.appendChild(mark)
      cursor = end
    }

    // Remaining text after last match
    if (cursor < originalText.length) {
      fragment.appendChild(document.createTextNode(originalText.slice(cursor)))
    }

    textNode.parentNode.replaceChild(fragment, textNode)
  }
}
