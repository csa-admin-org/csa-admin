import { configure } from "lexxy"

const allowedTypes = ["image/png", "image/jpeg", "image/gif", "image/webp"]
const maxImageSize = 5 * 1024 * 1024

configure({
  default: {
    attachments: true,
    permittedAttachmentTypes: allowedTypes,
    toolbar: { upload: "image" },
    tables: true,
    remoteImages: false
  }
})

// Lexical binds meta/ctrl+U to underline before our listeners. The toolbar
// button is hidden; block the shortcut only while the editor has focus.
document.addEventListener(
  "keydown",
  (event) => {
    if (event.key !== "u" && event.key !== "U") return
    if (event.altKey || event.shiftKey) return
    if (!(event.metaKey || event.ctrlKey)) return
    if (!event.target.closest?.("lexxy-editor")) return

    event.preventDefault()
    event.stopPropagation()
  },
  true
)

document.addEventListener("lexxy:file-accept", (event) => {
  const file = event.detail?.file
  if (!file) return

  if (file.size > maxImageSize) {
    event.preventDefault()
    alert(document.body.dataset.lexxyFileTooLargeAlert)
  } else if (!allowedTypes.includes(file.type)) {
    event.preventDefault()
    alert(document.body.dataset.lexxyInvalidFileAlert)
  }
})

const labelAttributes = ["title", "placeholder", "aria-label"]
const chromeSelector = [
  "lexxy-toolbar",
  "lexxy-table-tools",
  "lexxy-attachment-toolbar",
  "dialog",
  ".lexxy-caption-editor"
].join(",")
const countLabels = [
  [/^(\d+) row$/, /^(\d+) rows$/, "__row_one", "__row_other"],
  [/^(\d+) column$/, /^(\d+) columns$/, "__column_one", "__column_other"]
]

function lexxyLabels() {
  if (lexxyLabels.cache) return lexxyLabels.cache

  lexxyLabels.cache = JSON.parse(document.body.dataset.lexxyLabels || "{}")

  return lexxyLabels.cache
}

function translated(labels, text) {
  if (labels[text]) return labels[text]

  for (const [one, other, oneKey, otherKey] of countLabels) {
    const single = text.match(one)
    if (single && labels[oneKey]) return `${single[1]} ${labels[oneKey]}`

    const plural = text.match(other)
    if (plural && labels[otherKey]) return `${plural[1]} ${labels[otherKey]}`
  }

  return null
}

function localizeNode(root, labels) {
  root.querySelectorAll(labelAttributes.map((name) => `[${name}]`).join(",")).forEach((element) => {
    labelAttributes.forEach((name) => {
      const value = element.getAttribute(name)
      const next = value && translated(labels, value)
      if (next) element.setAttribute(name, next)
    })
  })

  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
  let node = walker.nextNode()
  while (node) {
    const trimmed = node.nodeValue.trim()
    const next = translated(labels, trimmed)
    if (next) node.nodeValue = node.nodeValue.replace(trimmed, next)
    node = walker.nextNode()
  }
}

function localizeLexxy(editor) {
  const labels = lexxyLabels()
  if (!Object.keys(labels).length) return

  editor.querySelectorAll(chromeSelector).forEach((root) => localizeNode(root, labels))
}

function watchLexxy(editor) {
  if (editor.dataset.lexxyLocalized) return
  editor.dataset.lexxyLocalized = "true"

  localizeLexxy(editor)
  new MutationObserver(() => localizeLexxy(editor)).observe(editor, {
    childList: true,
    subtree: true
  })
}

document.addEventListener("lexxy:editor-initialized", (event) => {
  watchLexxy(event.target)
})

document.querySelectorAll("lexxy-editor").forEach(watchLexxy)
