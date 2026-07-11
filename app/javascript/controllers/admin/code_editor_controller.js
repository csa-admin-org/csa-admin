import { Controller } from "@hotwired/stimulus"
import { hide } from "components/utils"
import { debounce } from "throttle-debounce"
import { CodeJar } from "codejar"
import { withLineNumbers } from "codejar-linenumbers"
import Prism from "prismjs"

window.Prism = Prism

import "prismjs/components/prism-yaml"
import "prismjs/components/prism-markup-templating"
import "prismjs/components/prism-liquid"

export default class extends Controller {
  static get targets() {
    return ["editor", "form"]
  }
  static get values() {
    return { previewPath: String }
  }

  initialize() {
    this.fetchPreview = debounce(500, this.fetchPreview.bind(this))
    this.previewRevision = 0
  }

  editorTargetConnected(element) {
    hide(element)

    const editDiv = document.createElement("div")
    editDiv.className = "codejar-editor"

    const mode = element.dataset.mode || "markup"
    const languageClass = `language-${mode}`
    editDiv.classList.add(languageClass)

    if (element.dataset.maxHeight) {
      editDiv.style.maxHeight = element.dataset.maxHeight
    }

    element.parentNode.insertBefore(editDiv, element)

    const highlight = (editor) => {
      const code = editor.textContent
      const grammar = Prism.languages[mode] || Prism.languages.markup
      editor.innerHTML = Prism.highlight(code, grammar, mode)
    }

    this.jar = CodeJar(
      editDiv,
      withLineNumbers(highlight, {
        width: "45px",
        backgroundColor: "transparent"
      }),
      {
        tab: "  ",
        indentOn: /[{([]$/,
        addClosing: true,
        history: true,
        catchTab: true,
        preserveIdent: true
      }
    )

    this.jar.updateCode(element.value)

    this.jar.onUpdate((code) => {
      element.value = code
      this.updatePreview()
    })
  }

  disconnect() {
    this.fetchPreview.cancel?.()
    this.invalidatePreview()
    this.jar?.destroy()
  }

  updatePreview() {
    this.invalidatePreview()
    this.fetchPreview(this.previewRevision)
  }

  invalidatePreview() {
    this.previewRevision += 1
    this.previewAbortController?.abort()
    this.previewAbortController = null
  }

  async fetchPreview(revision) {
    const path = this.previewPathValue

    if (!this.hasFormTarget || !path) return

    const abortController = new AbortController()
    this.previewAbortController = abortController

    const formData = new FormData(this.formTarget)
    formData.delete("_method") // remove PATCH Rails form _method
    const params = new URLSearchParams(formData)

    try {
      const response = await fetch(path, {
        method: "POST",
        body: params,
        signal: abortController.signal
      })
      const js = await response.text()

      if (abortController.signal.aborted || revision !== this.previewRevision) return

      eval(js)
    } catch (error) {
      if (error.name !== "AbortError") console.error(error)
    } finally {
      if (this.previewAbortController === abortController) {
        this.previewAbortController = null
      }
    }
  }
}
